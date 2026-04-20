/**
 * 分红记录数据模型
 * 来源：东方财富 RPT_LICO_FN_CPD 接口
 */

/** 分红类型 */
export enum DividendType {
  MidYear = '中报',   // 中期分红
  FullYear = '年报',  // 年度分红
  Other = '其他'
}

/** 单条分红记录 */
export class DividendRecord {
  payYear: string = '';      // 利润归属年度
  noticeDate: string = '';   // 公告日期
  exDate: string = '';      // 除权除息日
  desc: string = '';         // 分红方案描述 "10派16.20元(含税)"
  perShare: number = 0;      // 每股派息金额
  isPaid: boolean = false;   // 是否已派息到账
  type: DividendType = DividendType.Other;

  /**
   * 从东方财富 API 原始数据构建
   */
  static fromApiData(item: Record<string, string | number>): DividendRecord {
    const record = new DividendRecord();

    record.payYear = String(item['PAYYEAR'] ?? '');
    record.noticeDate = String(item['NOTICE_DATE'] ?? '').substring(0, 10);
    record.exDate = String(item['EITIME'] ?? '').substring(0, 10);
    record.desc = String(item['ASSIGNDSCRPT'] ?? '');
    record.perShare = DividendRecord.parseDividendPerShare(record.desc);
    record.isPaid = DividendRecord.checkIfPaid(record.exDate);
    record.type = DividendRecord.detectType(record.noticeDate);

    return record;
  }

  /**
   * 解析 ASSIGNDSCRPT，提取每股派息
   * 格式: "10派276.73元(含税,扣税后249.057元)"
   * 返回: 27.673
   */
  static parseDividendPerShare(desc: string): number {
    if (!desc) {
      return 0;
    }
    const match = desc.match(/(\d+)派([\d.]+)元/);
    if (match) {
      return parseFloat(match[2]) / parseInt(match[1]);
    }
    return 0;
  }

  /**
   * 检查是否已派息（根据除权除息日判断）
   */
  static checkIfPaid(exDate: string): boolean {
    if (!exDate) {
      return false;
    }
    const exDateMs = new Date(exDate).getTime();
    const nowMs = Date.now();
    return exDateMs <= nowMs;
  }

  /**
   * 根据公告日期判断是中报还是年报
   */
  static detectType(noticeDate: string): DividendType {
    if (!noticeDate) {
      return DividendType.Other;
    }
    const month = parseInt(noticeDate.substring(5, 7));
    if (month >= 3 && month <= 5) {
      return DividendType.FullYear; // 年报
    } else if (month >= 7 && month <= 9) {
      return DividendType.MidYear;  // 中报
    }
    return DividendType.Other;
  }
}

/** 年度分红汇总 */
export class YearlyDividend {
  year: string = '';
  totalPerShare: number = 0;  // 全年每股合计
  details: DividendRecord[] = [];
  hasMidYear: boolean = false;
  hasFullYear: boolean = false;
}
