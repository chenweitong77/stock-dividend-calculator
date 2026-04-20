/**
 * 股票行情数据模型
 * 来源：新浪财经 hq.sinajs.cn
 */
export class StockInfo {
  code: string = '';         // 股票代码
  name: string = '';         // 股票名称
  open: number = 0;         // 开盘价
  prevClose: number = 0;     // 昨收价
  current: number = 0;      // 当前价
  high: number = 0;         // 今日最高
  low: number = 0;          // 今日最低

  /**
   * 从新浪财经原始数据解析
   * 格式: var hq_str_sh600519="贵州茅台,现价,昨收,开盘,最高,最低,..."
   */
  static parse(raw: string, code: string): StockInfo {
    const info = new StockInfo();
    const match = raw.match(/"([^"]+)"/);
    if (!match) {
      return info;
    }

    const fields = match[1].split(',');
    if (fields.length < 6) {
      return info;
    }

    info.code = code;
    info.name = fields[0].trim();
    info.open = parseFloat(fields[1]) || 0;
    info.prevClose = parseFloat(fields[2]) || 0;
    info.current = parseFloat(fields[3]) || 0;
    info.high = parseFloat(fields[4]) || 0;
    info.low = parseFloat(fields[5]) || 0;

    return info;
  }
}
