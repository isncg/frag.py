# This example opens an image, and offsets the red, green, and blue channels to create a glitchy RGB split effect.
from pathlib import Path
from array import array

import moderngl
import moderngl_window
import json

cfg = json.load(open('config.json', 'r'))

class App(moderngl_window.WindowConfig):
    window_size = cfg['window']['width'], cfg['window']['height']
    resource_dir = Path(__file__).parent.resolve()
    aspect_ratio = None

    def setTextures(self):
        loc = 0
        for i in cfg['uniforms']:
            u = cfg['uniforms'][i]
            if u['type'] == 'sampler2D':
                tex = self.load_texture_2d(u['value'])
                self.textureMap[i] = tex
                print('Loaded texture ', i, u['value'])
                univar = self.program.get(i, None)
                if univar is not None:
                    tex.use(loc)
                    univar.value = loc
                    loc+=1

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
        
        self.textureMap = dict()
        print('Window size ',self.window_size)

        self.loadProgram()
        self.setBuffers()
        self.setTextures()

    def render(self, time, frame_time):
        p_time = self.program.get("time", None)
        if p_time is not None:
            p_time.value = time
        self.quad.render(mode=moderngl.TRIANGLE_STRIP)

if __name__ == "__main__":
    App.run()