import polars as pl


def solve_1brc_polars_optimized(file_path: str):
    """
    Solves the One Billion Row Challenge using a corrected and optimized Polars implementation
    that is compatible with a wider range of Polars versions.

    Args:
        file_path: The path to the measurements.txt file.
    """
    # Define a precise schema for fast parsing and lower memory usage
    schema = {"station": pl.Categorical, "measurement": pl.Float32}

    # Lazily scan the CSV file.
    # The 'comment_char' argument has been removed for compatibility.
    lazy_df = pl.scan_csv(
        file_path,
        separator=";",
        has_header=False,
        schema=schema,
    )

    # Group by station and perform aggregations.
    result = (
        lazy_df.group_by("station")
        .agg(
            pl.min("measurement").alias("min"),
            pl.mean("measurement").alias("mean"),
            pl.max("measurement").alias("max"),
        )
        .sort("station")
    )

    # Use Polars expressions for fast, vectorized string formatting.
    formatted_result = result.select(
        (
            pl.col("station").cast(pl.Utf8)
            + pl.lit("=")
            + (pl.col("min").round(1).cast(pl.Utf8))
            + pl.lit("/")
            + (pl.col("mean").round(1).cast(pl.Utf8))
            + pl.lit("/")
            + (pl.col("max").round(1).cast(pl.Utf8))
        ).alias("output_str")
    )

    # Collect the results using the modern 'engine="streaming"' API for memory efficiency.
    final_output = formatted_result.collect(engine="streaming")

    print(final_output.head())
    # Efficiently print all formatted lines at once.
    # print("{" + ", \n".join(final_output["output_str"].to_list()) + "}")


if __name__ == "__main__":
    import time

    file_to_process = "measurements.txt"
    try:
        # A simple check to see if the file is accessible
        with open(file_to_process, "r") as f:
            pass
    except FileNotFoundError:
        print(f"Error: The data file '{file_to_process}' was not found.")
        print(
            "Please generate it first using the original 1BRC repository"
            " script."
        )
    else:
        start_time = time.time()
        solve_1brc_polars_optimized(file_to_process)
        end_time = time.time()
        print(f"\nExecution time: {end_time - start_time:.2f} seconds")
