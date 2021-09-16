# This example opens an image, and offsets the red, green, and blue channels to create a glitchy RGB split effect.
from logging import Logger
from pathlib import Path
from array import array
from sys import argv

import moderngl
import moderngl_window
import json

from argparse import ArgumentParser, Namespace
from moderngl_window.context.base.window import WindowConfig

from moderngl_window.timers.clock import Timer
from moderngl_window import logger

cfg = None#json.load(open('config.json', 'r'))

class App(moderngl_window.WindowConfig):
    resource_dir = Path(__file__).parent.resolve()
    aspect_ratio = None
    #cfg = json.load(open(argv.config, 'r'))
    def setUniforms(self):
        loc = 0
        for i in cfg['uniforms']:
            univar = self.program.get(i, None)
            if univar is None:
                continue
            u = cfg['uniforms'][i]
            value = u['value']
            if u['type'] == 'sampler2D':
                tex = self.load_texture_2d(value)
                self.textureMap[i] = tex
                print('Loaded texture ', i, value)
                tex.use(loc)
                univar.value = loc
                loc+=1
            elif u['type'] == 'vec2':
                univar.value = (value[0], value[1])

    def loadProgram(self):
        self.program = self.ctx.program(
            vertex_shader = open(cfg['shaders']['vert']).read(),
            fragment_shader = open(cfg['shaders']['frag']).read(),          
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
                    -1, -1, 0, 0, # lower left
                     1,  1, 1, 1, # upper right
                     1, -1, 1, 0, # lower right
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
        self.textureMap = dict()
        print('Window size ',self.window_size)

        self.loadProgram()
        self.setBuffers()
        self.setUniforms()

    def render(self, time, frame_time):
        p_time = self.program.get("time", None)
        if p_time is not None:
            p_time.value = time
        self.quad.render(mode=moderngl.TRIANGLE_STRIP)

def run_window_config(config_cls: WindowConfig, timer=None, args=None) -> None:
    """
    Run an WindowConfig entering a blocking main loop

    Args:
        config_cls: The WindowConfig class to render
    Keyword Args:
        timer: A custom timer instance
        args: Override sys.args
    """
    global cfg
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


if __name__ == '__main__':
    run_window_config(App)