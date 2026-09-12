pub const MTLPixelFormat = usize;
pub const MTLPixelFormatBGRA8Unorm: MTLPixelFormat = 80;
pub const MTLPixelFormatBGR10A2Unorm: MTLPixelFormat = 94;

pub const MTLTextureUsage = usize;
pub const MTLTextureUsageShaderRead: MTLTextureUsage = 1 << 0;
pub const MTLTextureUsageShaderWrite: MTLTextureUsage = 1 << 1;

pub const MTLSize = extern struct {
    width: usize,
    height: usize,
    depth: usize,
};
