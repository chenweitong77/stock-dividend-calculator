/**
 * 分红数据服务
 * 数据来源：东方财富 datacenter-web.eastmoney.com
 * 接口：reportName=RPT_LICO_FN_CPD
 */
import { HttpUtil } from '../util/HttpUtil';
import { DividendRecord, YearlyDividend, DividendType } from '../model/DividendRecord';

interface ApiResponse {
  success: boolean;
  result?: {
    data: Record<string, string | number>[];
  };
  message?: string;
}

export class DividendService {
  /**
   * 获取股票历史分红记录
   * @param code 股票代码（6位数字，如 "601318"）
   * @param pageSize 返回记录数量，默认20条
   */
  static async getDividendRecords(code: string, pageSize: number = 20): Promise<DividendRecord[]> {
    try {
      const url = `https://datacenter-web.eastmoney.com/api/data/v1/get?` +
        `reportName=RPT_LICO_FN_CPD&` +
        `columns=SECURITY_CODE,SECURITY_NAME_ABBR,REPORTDATE,ASSIGNDSCRPT,PAYYEAR,ZXGXL,NOTICE_DATE,EITIME&` +
        `filter=(SECURITY_CODE%3D%22${code}%22)&` +
        `pageNumber=1&pageSize=${pageSize}&source=WEB&client=WEB`;

      const raw = await HttpUtil.get(url, {
        'Referer': 'https://data.eastmoney.com/'
      });

      const response: ApiResponse = JSON.parse(raw);

      if (!response.success || !response.result) {
        console.error('获取分红数据失败:', response.message);
        return [];
      }

      return response.result.data.map(item => DividendRecord.fromApiData(item));

    } catch (e) {
      console.error(`获取分红记录失败: ${code}`, e);
      return [];
    }
  }

  /**
   * 获取指定年度的分红汇总
   * @param records 分红记录列表
   * @param year 年份（字符串，如 "2025"）
   */
  static getYearlyDividend(records: DividendRecord[], year: string): YearlyDividend {
    const yearly = new YearlyDividend();
    yearly.year = year;

    for (const record of records) {
      // 按 PAYYEAR（利润归属年度）归类
      if (record.payYear !== year) {
        continue;
      }

      // 跳过无现金分红的记录
      if (record.perShare <= 0) {
        continue;
      }

      yearly.details.push(record);
      yearly.totalPerShare += record.perShare;

      // 判断包含中报还是年报
      if (record.type === DividendType.MidYear) {
        yearly.hasMidYear = true;
      } else if (record.type === DividendType.FullYear) {
        yearly.hasFullYear = true;
      }
    }

    // 保留4位小数
    yearly.totalPerShare = Math.round(yearly.totalPerShare * 10000) / 10000;

    return yearly;
  }
}
