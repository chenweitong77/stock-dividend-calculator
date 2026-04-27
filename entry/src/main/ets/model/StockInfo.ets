/**
 * 股票行情数据模型
 * 来源：东方财富 push2.eastmoney.com（新浪 hq.sinajs.cn 已弃用）
 * 东方财富字段说明：f43=当前价(分), f57=代码, f58=名称, f17=昨收, f18=开盘, f15=今高, f16=今低
 */

/** 东方财富行情接口响应 */
interface EastMoneyStockData {
  f43: number | null;  // 当前价(分)
  f57: string;         // 代码
  f58: string;         // 名称
  f17: number | null;  // 昨收价(分)
  f18: number | null;  // 开盘价(分)
  f15: number | null;  // 今日最高(分)
  f16: number | null;  // 今日最低(分)
}

interface EastMoneyResponse {
  data: EastMoneyStockData | null;
}

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

  /**
   * 从东方财富原始 JSON 数据解析
   * 接口: push2.eastmoney.com/api/qt/stock/get?secid=1.600519&fields=f43,f57,f58,f17,f18,f15,f16
   * 字段: f43=当前价(分), f17=昨收价(分), f18=开盘价(分), f15=今日最高(分), f16=今日最低(分)
   */
  static parseEastMoney(raw: string, code: string): StockInfo {
    const info = new StockInfo();
    try {
      const json: EastMoneyResponse = JSON.parse(raw);
      const d: EastMoneyStockData | null = json.data;
      if (!d) {
        return info;
      }

      info.code = code;
      info.name = d.f58 || '';
      // 东方财富价格单位是"分"，需除以100转为"元"
      info.current = (Number(d.f43) || 0) / 100;
      info.prevClose = (Number(d.f17) || 0) / 100;
      info.open = (Number(d.f18) || 0) / 100;
      info.high = (Number(d.f15) || 0) / 100;
      info.low = (Number(d.f16) || 0) / 100;

    } catch (e) {
      console.error('解析东方财富行情数据失败', e);
    }
    return info;
  }
}
