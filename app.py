from pathlib import Path
from array import array

import moderngl
import moderngl_window
import json

from moderngl_window.context.base.window import WindowConfig
from moderngl_window.timers.clock import Timer
from moderngl_window import logger

from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler


class App(moderngl_window.WindowConfig):
    resource_dir = Path(__file__).parent.resolve()
    aspect_ratio = None
    #cfg = json.load(open(argv.config, 'r'))

    def setUniforms(self):
        loc = 0
        for i in self.cfg['uniforms']:
            univar = self.program.get(i, None)
            if univar is None:
                continue
            u = self.cfg['uniforms'][i]
            value = u['value']
            if u['type'] == 'sampler2D':
                tex = self.load_texture_2d(value)
                self.textureMap[i] = tex
                print('Loaded texture ', i, value)
                tex.use(loc)
                univar.value = loc
                loc += 1
            elif u['type'] == 'vec2' or u['type'] == 'ivec2':
                univar.value = (value[0], value[1])
            elif u['type'] == 'vec3' or u['type'] == 'ivec3':
                univar.value = (value[0], value[1], value[2])
            else:
                univar.value = value

    def onFileChange(self, src_path):
        if(src_path == './'+self.argv.config or src_path == '.\\'+self.argv.config):
            self.needReloadUniform = True

    def loadProgram(self):
        self.program = self.ctx.program(
            vertex_shader=open(self.cfg['shaders']['vert']).read(),
            fragment_shader=open(self.cfg['shaders']['frag']).read(),
        )

    def setBuffers(self):
        self.fbo = self.ctx.framebuffer(
            color_attachments=[self.ctx.texture(self.window_size, 4)]
        )

        # Fullscreen quad in NDC
        self.vertices = self.ctx.buffer(
            array(
                'f',
                [
                    # Triangle strip creating a fullscreen quad
                    # x, y, u, v
                    -1,  1, 0, 1,  # upper left
                    -1, -1, 0, 0,  # lower left
                    1,  1, 1, 1,  # upper right
                    1, -1, 1, 0,  # lower right
                ]
            )
        )

        self.quad = self.ctx.vertex_array(
            self.program,
            [
                (self.vertices, '2f 2f', 'in_position', 'in_uv'),
            ]
        )

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        print("ARGV: ", self.argv)
        self.cfg = json.load(open(self.argv.config, 'r'))
        self.textureMap = dict()
        print('Window size ', self.window_size)

        self.loadProgram()
        self.setBuffers()
        self.needReloadUniform = True
        #self.setUniforms()

        event_handler = FileChangeHandler(self.onFileChange)
        self.observer = Observer()
        self.observer.schedule(event_handler,  path='./',  recursive=False)
        self.observer.start()

    def render(self, time, frame_time):
        p_time = self.program.get("time", None)
        if p_time is not None:
            p_time.value = time
        self.quad.render(mode=moderngl.TRIANGLE_STRIP)
        if self.needReloadUniform:
            self.cfg = json.load(open(self.argv.config, 'r'))
            self.setUniforms()
            self.needReloadUniform = False


def run_window_config(config_cls: WindowConfig, timer=None, args=None) -> None:
    """
    Run an WindowConfig entering a blocking main loop

    Args:
        config_cls: The WindowConfig class to render
    Keyword Args:
        timer: A custom timer instance
        args: Override sys.args
    """
    #global cfg
    moderngl_window.setup_basic_logging(config_cls.log_level)
    parser = moderngl_window.create_parser()
    config_cls.add_arguments(parser)
    parser.add_argument('-cfg', '--config', default='config.json')
    values = moderngl_window.parse_args(args=args, parser=parser)
    cfg = json.load(open(values.config, 'r'))
    config_cls.argv = values
    config_cls.window_size = cfg['window']['width'], cfg['window']['height']
    window_cls = moderngl_window.get_local_window_cls(values.window)

    # Calculate window size
    size = values.size or config_cls.window_size
    size = int(size[0] * values.size_mult), int(size[1] * values.size_mult)

    # Resolve cursor
    show_cursor = values.cursor
    if show_cursor is None:
        show_cursor = config_cls.cursor

    window = window_cls(
        title=config_cls.title,
        size=size,
        fullscreen=config_cls.fullscreen or values.fullscreen,
        resizable=values.resizable
        if values.resizable is not None
        else config_cls.resizable,
        gl_version=config_cls.gl_version,
        aspect_ratio=config_cls.aspect_ratio,
        vsync=values.vsync if values.vsync is not None else config_cls.vsync,
        samples=values.samples if values.samples is not None else config_cls.samples,
        cursor=show_cursor if show_cursor is not None else True,
    )
    window.print_context_info()
    moderngl_window.activate_context(window=window)
    timer = timer or Timer()
    window.config = config_cls(ctx=window.ctx, wnd=window, timer=timer)

    # Swap buffers once before staring the main loop.
    # This can trigged additional resize events reporting
    # a more accurate buffer size
    window.swap_buffers()
    window.set_default_viewport()

    timer.start()

    while not window.is_closing:
        current_time, delta = timer.next_frame()

        if window.config.clear_color is not None:
            window.clear(*window.config.clear_color)

        # Always bind the window framebuffer before calling render
        window.use()

        window.render(current_time, delta)
        if not window.is_closing:
            window.swap_buffers()

    _, duration = timer.stop()
    window.destroy()
    if duration > 0:
        logger.info(
            "Duration: {0:.2f}s @ {1:.2f} FPS".format(
                duration, window.frames / duration
            )
        )


class FileChangeHandler(FileSystemEventHandler):
    def __init__(self, action):
        self.action = action

    def on_modified(self,  event):
        self.action(event.src_path)


if __name__ == '__main__':
    run_window_config(App)
