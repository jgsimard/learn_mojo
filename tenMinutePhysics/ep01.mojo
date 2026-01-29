from python import Python, PythonObject


@fieldwise_init
struct Vector2(Copyable):
    var x: Float64
    var y: Float64


@fieldwise_init
struct Ball(Copyable):
    var radius: Float64
    var pos: Vector2
    var vel: Vector2


struct State:
    var gravity: Vector2
    var dt: Float64
    var ball: Ball
    var sim_min_width: Float64

    fn __init__(out self):
        self.gravity = Vector2(0.0, -10.0)
        self.dt = 1.0 / 60.0
        self.ball = Ball(
            radius=0.2, pos=Vector2(0.2, 0.2), vel=Vector2(10.0, 15.0)
        )
        self.sim_min_width = 20.0

    fn simulate(mut state: Self, sim_width: Float64):
        # Physics integration
        state.ball.vel.x += state.gravity.x * state.dt
        state.ball.vel.y += state.gravity.y * state.dt
        state.ball.pos.x += state.ball.vel.x * state.dt
        state.ball.pos.y += state.ball.vel.y * state.dt

        # Boundary collisions
        if state.ball.pos.x < 0.0:
            state.ball.pos.x = 0.0
            state.ball.vel.x = -state.ball.vel.x

        if state.ball.pos.x > sim_width:
            state.ball.pos.x = sim_width
            state.ball.vel.x = -state.ball.vel.x

        if state.ball.pos.y < 0.0:
            state.ball.pos.y = -state.ball.pos.y
            state.ball.vel.y = -state.ball.vel.y


fn main() raises:
    var pg = Python.import_module("pygame")
    pg.init()

    var screen_dim = Python.tuple(800, 600)
    var screen = pg.display.set_mode(screen_dim, pg.RESIZABLE)
    pg.display.set_caption("Ten Minute Physics - Episode 1")

    var state = State()
    var clock = pg.time.Clock()
    var running = True

    while running:
        # events
        for event in pg.event.get():
            if event.type == pg.QUIT:
                running = False

        # scaling
        var w = Float64(py=screen.get_width())
        var h = Float64(py=screen.get_height())

        var scale = (
            w / state.sim_min_width if w < h else h / state.sim_min_width
        )

        var sim_width = w / scale

        # physics
        state.simulate(sim_width)

        # rendering
        var color_white = Python.tuple(255, 255, 255)
        screen.fill(color_white)

        var px = state.ball.pos.x * scale
        var py = h - (state.ball.pos.y * scale)
        var pr = state.ball.radius * scale

        var color = Python.tuple(255, 0, 0)
        var pos = Python.tuple(px, py)
        pg.draw.circle(screen, color, pos, pr)

        pg.display.flip()

        clock.tick(60)  # 60 FPS

    pg.quit()
