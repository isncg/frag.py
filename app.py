# This example opens an image, and offsets the red, green, and blue channels to create a glitchy RGB split effect.
from pathlib import Path
from array import array

from PIL import Image

import moderngl
import moderngl_window


class ImageProcessing(moderngl_window.WindowConfig):
    window_size = 1076//2, 1436//2
    resource_dir = Path(__file__).parent.resolve()
    aspect_ratio = None

    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.image_processing = ImageTransformer(self.ctx, self.window_size)
        self.texture = self.load_texture_2d("img/test2.jpg")

    def render(self, time, frame_time):
        self.image_processing.render(self.texture, time, target=self.ctx.screen)

        # Headless
        #self.image_processing.render(self.texture)
        #self.image_processing.write("output.png")


class ImageTransformer:

    def __init__(self, ctx, size, program=None):
        self.ctx = ctx
        self.size = size
        self.program = None
        self.fbo = self.ctx.framebuffer(
            color_attachments=[self.ctx.texture(self.size, 4)]
        )

        # Create some default program if needed
        if not program:
            self.program = self.ctx.program(
                vertex_shader = open("shader/vert.glsl").read(),
                fragment_shader = open("shader/frag.glsl").read(),          
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

    def render(self, texture, time, target=None):
        if target:
            target.use()
        else:
            self.fbo.use()

        texture.use(0)
        p_time = self.program.get("time", None)
        if p_time is not None:
            p_time.value = time
        #self.program["time2"].value = time
        self.quad.render(mode=moderngl.TRIANGLE_STRIP)

    def write(self, name):
        image = Image.frombytes("RGBA", self.fbo.size, self.fbo.read(components=4))
        image = image.transpose(Image.FLIP_TOP_BOTTOM)
        image.save(name, format="png")


if __name__ == "__main__":
    ImageProcessing.run()