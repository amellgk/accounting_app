export function errorHandler(err, req, res, next) {
  console.error('Error:', err.message);
  
  if (err.code === 'P2002') {
    return res.status(409).json({ error: '数据已存在' });
  }
  
  if (err.code === 'P2025') {
    return res.status(404).json({ error: '记录未找到' });
  }

  res.status(err.status || 500).json({
    error: err.message || '服务器内部错误',
  });
}
