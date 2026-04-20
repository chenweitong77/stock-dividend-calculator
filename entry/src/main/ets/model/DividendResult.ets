/**
 * 分红计算结果数据模型
 */

/** 用户持仓基本信息 */
export class StockBasicInfo {
  code: string = '';
  name: string = '';
  costPrice: number = 0;
  shares: number = 0;
  totalCost: number = 0;
  currentPrice: number = 0;
  prevClose: number = 0;
  marketValue: number = 0;
  floatingPnL: number = 0;
  floatingRate: number = 0;
}

/** 分红计算完整结果 */
export class DividendResult {
  stock: StockBasicInfo = new StockBasicInfo();
  year: string = '';
  yearlyPerShare: number = 0;
  totalDividend: number = 0;
  yieldRateByCost: number = 0;
  yieldRateByPrice: number = 0;
  details: DividendRecord[] = [];
  isAnnounced: boolean = false;
}

/** 引入 DividendRecord */
import { DividendRecord } from './DividendRecord';
