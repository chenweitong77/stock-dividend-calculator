/**
 * 股票行情服务
 * 数据来源：东方财富 push2.eastmoney.com（新浪 hq.sinajs.cn 已弃用，频繁 403）
 */
import { HttpUtil } from '../util/HttpUtil';
import { StockInfo } from '../model/StockInfo';

export class StockService {
  /**
   * 获取股票实时行情
   * @param code 股票代码（6位数字，如 "601318"）
   */
  static async getStockPrice(code: string): Promise<StockInfo | null> {
    try {
      // 东方财富 secid: 1=上海, 0=深圳
      const secid = code.startsWith('6') ? '1.' + code : '0.' + code;
      const url = 'https://push2.eastmoney.com/api/qt/stock/get?' +
        'secid=' + secid +
        '&fields=f43,f57,f58,f107,f50,f169,f170,f15,f16';

      const raw = await HttpUtil.get(url, {
        'Referer': 'https://quote.eastmoney.com/',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
      });

      return StockInfo.parseEastMoney(raw, code);

    } catch (e) {
      console.error('获取股票行情失败: ' + code, e);
      return null;
    }
  }
}
