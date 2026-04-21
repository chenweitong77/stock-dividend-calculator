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
    record.type = DividendRecord.detectType(record.exDate, record.noticeDate);

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
   * 根据除权日期（exDate）判断分红类型：
   * - 年报: 除权在次年3-5月
   * - 中报: 除权在7-9月
   * - 三季报: 除权在10-11月
   * - 一季报: 除权在4-5月（需结合公告日期区分）
   */
  static detectType(exDate: string, noticeDate: string): DividendType {
    if (!exDate) {
      return DividendType.MidYear;
    }

    const month = parseInt(exDate.substring(5, 7));

    if (3 <= month && month <= 5) {
      // 3-5月：年报或一季报，用公告日期区分
      // 一季报公告在4-5月，年报公告在2-3月
      if (noticeDate && noticeDate.length >= 7) {
        const noticeMonth = parseInt(noticeDate.substring(5, 7));
        if (4 <= noticeMonth && noticeMonth <= 5) {
          return DividendType.Q1; // 一季报
        }
      }
      return DividendType.FullYear;
    } else if (7 <= month && month <= 9) {
      return DividendType.MidYear;
    } else if (10 <= month && month <= 11) {
      return DividendType.Q3; // 三季报
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
