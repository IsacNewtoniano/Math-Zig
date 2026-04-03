pub fn Array() type{
  return struct {
    Multiply     : f32 = 2.0,
    Size    : usize,
    Blocks       : [*]*u8,
  };
}