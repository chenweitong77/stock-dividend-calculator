/**
 * 分红计算结果数据模型
 */

import { DividendRecord } from './DividendRecord';

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

/** 单个年份的分红汇总 */
export class YearSummary {
  perShare: number = 0;        // 每股分红（元）
  totalDividend: number = 0;    // 年度总分红（元）
  yieldRate: number = 0;        // 成本价股息率（%）
  hasDetail: boolean = false;    // 是否有明细
}

/** 历史年度对比条目 */
export class HistoricalComparison {
  year: string = '';             // 年度
  perShare: number = 0;          // 每股分红（元）
  costYield: number = 0;         // 成本价股息率（%）
  currentYield: number = 0;      // 当前价股息率（%）
}

/** 分红计算完整结果 */
export class DividendResult {
  stock: StockBasicInfo = new StockBasicInfo();
  year: string = '';                         // 当前选中年份
  yearlyPerShare: number = 0;                // 每股分红（元）
  totalDividend: number = 0;                 // 年度总分红（元）
  yieldRateByCost: number = 0;              // 成本价股息率（%）
  yieldRateByPrice: number = 0;             // 当前价股息率（%）
  costRecoveryYears: number = 0;             // 预计回收成本（年）
  details: DividendRecord[] = [];            // 分红明细
  isAnnounced: boolean = false;               // 是否已公告
  isPaid: boolean = false;                    // 是否已派息
  noDividend: boolean = false;                // 是否有无分红记录
  message: string = '';                       // 提示信息

  // ======== 新增：多年份支持 ========
  /** 所有可用年份的分红汇总（key: 年份如 '2025'） */
  allYearsSummary: Record<string, YearSummary> = {};

  /** 历史年度对比（2024/2023/2022） */
  historicalComparison: HistoricalComparison[] = [];
}
