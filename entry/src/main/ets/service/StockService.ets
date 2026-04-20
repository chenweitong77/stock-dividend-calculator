/**
 * 股票行情服务
 * 数据来源：新浪财经 hq.sinajs.cn
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
      // 上海: sh 前缀, 深圳: sz 前缀
      const prefix = code.startsWith('6') ? 'sh' : 'sz';
      const url = `https://hq.sinajs.cn/list=${prefix}${code}`;

      const raw = await HttpUtil.get(url, {
        'Referer': 'https://finance.sina.com.cn'
      });

      return StockInfo.parse(raw, code);
    } catch (e) {
      console.error(`获取股票行情失败: ${code}`, e);
      return null;
    }
  }
}
