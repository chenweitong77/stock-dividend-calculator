/**
 * 分红记录数据模型
 * 来源：东方财富 RPT_LICO_FN_CPD 接口
 */

/** 分红类型 */
export enum DividendType {
  Q1 = '一季报',    // 一季报分红
  MidYear = '中报',  // 中期分红
  Q3 = '三季报',    // 三季报分红
  FullYear = '年报'  // 年度分红
}

/** 单条分红记录 */
export class DividendRecord {
  payYear: string = '';      // 利润归属年度
  noticeDate: string = '';   // 公告日期
  exDate: string = '';      // 除权除息日
  desc: string = '';         // 分红方案描述 "10派16.20元(含税)"
  perShare: number = 0;      // 每股派息金额
  isPaid: boolean = false;   // 是否已派息到账
  type: DividendType = DividendType.MidYear;

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
    record.type = DividendRecord.detectType(record.exDate, record.noticeDate, record.payYear);

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
   * 根据公告日期年份判断分红类型：
   * - 年报: 公告年份 = 归属年份 + 1（所有月份都是年报）
   * - 一季报: 公告年份 = 归属年份，除权在3-6月
   * - 中报: 公告年份 = 归属年份，除权在7-9月
   * - 三季报: 公告年份 = 归属年份，除权在10-12月
   */
  static detectType(exDate: string, noticeDate: string, payYear: string): DividendType {
    if (!noticeDate) {
      return DividendType.MidYear;
    }

    const noticeYear = noticeDate.substring(0, 4);
    const nextYear = (parseInt(payYear) + 1).toString();

    // 规则：公告年份 = 归属年份 + 1 → 年报
    if (noticeYear === nextYear) {
      return DividendType.FullYear;
    }

    // 公告年份 = 归属年份，看除权月份
    if (noticeYear === payYear) {
      const month = parseInt(exDate.substring(5, 7));
      if (3 <= month && month <= 6) {
        return DividendType.Q1;
      } else if (7 <= month && month <= 9) {
        return DividendType.MidYear;
      } else if (10 <= month && month <= 12) {
        return DividendType.Q3;
      }
    }

    return DividendType.MidYear;
  }
}

/** 年度分红汇总 */
export class YearlyDividend {
  year: string = '';
  totalPerShare: number = 0;  // 全年每股合计
  details: DividendRecord[] = [];
  hasQ1: boolean = false;       // 是否有 一季报 分红
  hasMidYear: boolean = false;  // 是否有 中报 分红
  hasQ3: boolean = false;       // 是否有 三季报 分红
  hasFullYear: boolean = false; // 是否有 年报 分红
}
