/**
 * 分红数据服务
 * 数据来源：东方财富 datacenter-web.eastmoney.com
 * 接口：reportName=RPT_LICO_FN_CPD
 */
import { HttpUtil } from '../util/HttpUtil';
import { DividendRecord, YearlyDividend, DividendType, ApiDataRecord } from '../model/DividendRecord';

/** API 响应结果数据 */
export class ApiResultData {
  data: ApiDataRecord[] = [];
}

/** API 响应结果 */
export class ApiResult {
  success: boolean = false;
  result: ApiResultData | null = null;
  message: string = '';
}

export class DividendService {
  /**
   * 获取股票历史分红记录
   * @param code 股票代码（6位数字，如 "601318"）
   * @param pageSize 返回记录数量，默认20条
   */
  static async getDividendRecords(code: string, pageSize: number = 20): Promise<DividendRecord[]> {
    try {
      // filter 表达式需要 URL 编码，避免特殊字符导致解析错误
      const filterExpr = '(SECURITY_CODE="' + code + '")';
      const encodedFilter = encodeURIComponent(filterExpr);
      const url = 'https://datacenter-web.eastmoney.com/api/data/v1/get?' +
        'reportName=RPT_LICO_FN_CPD&' +
        'columns=SECURITY_CODE,SECURITY_NAME_ABBR,REPORTDATE,ASSIGNDSCRPT,PAYYEAR,ZXGXL,NOTICE_DATE,EITIME&' +
        'filter=' + encodedFilter + '&' +
        'pageNumber=1&pageSize=' + pageSize + '&source=WEB&client=WEB';

      const raw = await HttpUtil.get(url, {
        'Referer': 'https://data.eastmoney.com/',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': '*/*'
      });

      const response: ApiResult = JSON.parse(raw);

      if (!response.success || !response.result) {
        console.error('获取分红数据失败:', response.message);
        return [];
      }

      const items = response.result.data;
      const results: DividendRecord[] = [];
      for (let i = 0; i < items.length; i++) {
        results.push(DividendRecord.fromApiData(items[i]));
      }
      return results;

    } catch (e) {
      console.error('获取分红记录失败: ' + code, e);
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

    for (let i = 0; i < records.length; i++) {
      const record = records[i];
      if (record.payYear !== year) {
        continue;
      }
      if (record.perShare <= 0) {
        continue;
      }

      yearly.details.push(record);
      yearly.totalPerShare += record.perShare;

      if (record.type === DividendType.Q1) {
        yearly.hasQ1 = true;
      } else if (record.type === DividendType.MidYear) {
        yearly.hasMidYear = true;
      } else if (record.type === DividendType.Q3) {
        yearly.hasQ3 = true;
      } else if (record.type === DividendType.FullYear) {
        yearly.hasFullYear = true;
      }
    }

    yearly.totalPerShare = Math.round(yearly.totalPerShare * 10000) / 10000;
    return yearly;
  }
}
