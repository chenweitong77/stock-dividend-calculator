/**
 * 股票搜索服务
 * 支持按股票名称或代码搜索，返回匹配的股票列表
 */
import { HttpUtil } from '../util/HttpUtil';

export interface StockSearchItem {
  code: string;
  name: string;
  market: string; // 'sh' 或 'sz'
}

/** 搜索结果 */
export interface SearchResult {
  stocks: StockSearchItem[];
  success: boolean;
  error?: string;
}

/** 东方财富搜索响应数据项 */
export class EMDataItem {
  SECURITY_CODE: string = '';
  SECURITY_NAME_ABBR: string = '';
}

/** 东方财富搜索响应结果 */
export class EMResult {
  data: EMDataItem[] = [];
}

/** 东方财富搜索响应 */
export class EastMoneyResponse {
  success: boolean = false;
  result: EMResult | null = null;
}

/** 东方财富建议响应数据项 */
export class SuggestDataItem {
  Code: string = '';
  Name: string = '';
}

/** 东方财富建议响应数据容器 */
export class QuotationCodeTable {
  Data: SuggestDataItem[] = [];
}

/** 东方财富建议响应 */
export class SuggestResponse {
  QuotationCodeTable: QuotationCodeTable | null = null;
}

/**
 * 静态映射表（常用股票，网络不稳定时也能搜索）
 */
const STATIC_STOCK_MAP: Record<string, string> = {
  '中国平安': '601318', '平安': '601318',
  '招商银行': '600036', '招商': '600036',
  '兴业银行': '601166', '交通银行': '601328',
  '工商银行': '601398', '工行': '601398',
  '建设银行': '601939', '建行': '601939',
  '中国银行': '601988', '中行': '601988',
  '农业银行': '601288', '农行': '601288',
  '平安银行': '000001', '浦发银行': '600000',
  '民生银行': '600016',
  '中国人寿': '601628', '人寿': '601628',
  '新华保险': '601336', '太保': '601601',
  '人保': '601319',
  '贵州茅台': '600519', '茅台': '600519',
  '五粮液': '000858', '泸州老窖': '000568',
  '山西汾酒': '600809', '汾酒': '600809',
  '洋河股份': '002304', '洋河': '002304',
  '伊利股份': '600887', '伊利': '600887',
  '海天味业': '603288', '海天': '603288',
  '格力电器': '000651', '格力': '000651',
  '美的集团': '000333', '美的': '000333',
  '海尔智家': '600690', '海尔': '600690',
  '比亚迪': '002594', '上汽集团': '600104',
  '长城汽车': '601633', '北汽蓝谷': '600733',
  '宁德时代': '300750', '宁德': '300750',
  '隆基绿能': '601012', '隆基': '601012',
  '通威股份': '600438',
  '恒瑞医药': '600276', '恒瑞': '600276',
  '迈瑞医疗': '300760', '药明康德': '603259',
  '爱尔眼科': '300015', '智飞生物': '300122',
  '长春高新': '000661',
  '中兴通讯': '000063', '海康威视': '002415',
  '京东方A': '000725', '立讯精密': '002475',
  '歌尔股份': '002241',
  '万科A': '000002', '万科': '000002',
  '保利发展': '600048', '招商蛇口': '001979',
  '中国石油': '601857', '中石油': '601857',
  '中国石化': '600028', '中国建筑': '601668',
  '中国神华': '601088', '神华': '601088',
  '中国联通': '600050', '中国核电': '601985',
  '长江电力': '600900', '中远海控': '601919',
  '顺丰控股': '002352', '万华化学': '600309',
  '三一重工': '600031', '海螺水泥': '600585',
  '东方财富': '300059', '东财': '300059',
  '中信证券': '600030', '华泰证券': '601688',
  '阿里巴巴': '09988', '腾讯': '00700',
  '美团': '03690', '小米': '01810',
  '百度': '09888',
};

/**
 * 反向映射：代码 → 名称
 */
const CODE_TO_NAME: Record<string, string> = {
  '601318': '中国平安',
  '600036': '招商银行',
  '600519': '贵州茅台',
  '000001': '平安银行',
  '000858': '五粮液',
  '002594': '比亚迪',
  '300750': '宁德时代',
};

/** 全量股票缓存（从东方财富搜索接口获取） */
let fullStockCache: Map<string, string> = new Map();
let cacheLoaded = false;

export class StockSearchService {
  static async search(keyword: string): Promise<SearchResult> {
    if (!keyword || keyword.trim().length === 0) {
      return { stocks: [], success: true };
    }

    const kw = keyword.trim().toLowerCase();
    const results: StockSearchItem[] = [];
    const seenCodes = new Set<string>();

    // 1. 精确匹配静态映射表
    const staticMatches = StockSearchService.searchStaticMap(kw);
    for (let i = 0; i < staticMatches.length; i++) {
      const item = staticMatches[i];
      if (!seenCodes.has(item.code)) {
        seenCodes.add(item.code);
        results.push(item);
      }
    }

    // 2. 如果静态表没找到足够结果，尝试从全量缓存搜索
    if (results.length < 5 && fullStockCache.size > 0) {
      const cacheMatches = StockSearchService.searchInCache(kw);
      for (let i = 0; i < cacheMatches.length; i++) {
        const item = cacheMatches[i];
        if (!seenCodes.has(item.code)) {
          seenCodes.add(item.code);
          results.push(item);
        }
      }
    }

    // 3. 如果缓存也没有，试从网络搜索
    if (results.length < 3) {
      const netMatches = await StockSearchService.searchFromNetwork(kw);
      for (let i = 0; i < netMatches.length; i++) {
        const item = netMatches[i];
        if (!seenCodes.has(item.code)) {
          seenCodes.add(item.code);
          results.push(item);
        }
      }
    }

    return { stocks: results.slice(0, 10), success: true };
  }

  private static searchStaticMap(kw: string): StockSearchItem[] {
    const results: StockSearchItem[] = [];
    const entries = Object.entries(STATIC_STOCK_MAP);

    for (let i = 0; i < entries.length; i++) {
      const name = entries[i][0];
      const code = entries[i][1];
      if (name.includes(kw) || kw.includes(name) || code.includes(kw)) {
        const market = code.startsWith('6') || code.startsWith('5') ? 'sh' : 'sz';
        const stdName = CODE_TO_NAME[code] || name;
        results.push({ code: code, name: stdName, market: market });
      }
    }

    const codeEntries = Object.entries(CODE_TO_NAME);
    for (let i = 0; i < codeEntries.length; i++) {
      const code = codeEntries[i][0];
      const name = codeEntries[i][1];
      if (code.includes(kw) || name.includes(kw)) {
        const market = code.startsWith('6') || code.startsWith('5') ? 'sh' : 'sz';
        if (!results.some((r: StockSearchItem) => r.code === code)) {
          results.push({ code: code, name: name, market: market });
        }
      }
    }

    return results.slice(0, 5);
  }

  private static searchInCache(kw: string): StockSearchItem[] {
    const results: StockSearchItem[] = [];

    if (kw.length === 6 && /^\d+$/.test(kw)) {
      const cacheCode = fullStockCache.get(kw);
      if (cacheCode) {
        const code = kw;
        const name = cacheCode;
        const market = code.startsWith('6') || code.startsWith('5') ? 'sh' : 'sz';
        results.push({ code: code, name: name, market: market });
      }
    } else {
      const keys = Array.from(fullStockCache.keys());
      for (let i = 0; i < keys.length; i++) {
        const name = keys[i];
        if (!/^\d+$/.test(name) && (name.includes(kw) || kw.includes(name))) {
          const code = fullStockCache.get(name);
          if (code && !results.some((r: StockSearchItem) => r.code === code)) {
            const market = code.startsWith('6') || code.startsWith('5') ? 'sh' : 'sz';
            results.push({ code: code, name: name, market: market });
          }
        }
      }
    }

    return results.slice(0, 5);
  }

  static async loadFullStockList(): Promise<void> {
    if (cacheLoaded && fullStockCache.size > 0) {
      return;
    }

    try {
      const url = 'https://datacenter-web.eastmoney.com/api/data/v1/get?' +
        'reportName=RPT_DMSK_TS_STOCKINFO&' +
        'columns=SECURITY_CODE,SECURITY_NAME_ABBR&' +
        'pageNumber=1&pageSize=5000&source=WEB&client=WEB';

      const raw = await HttpUtil.get(url, {
        'Referer': 'https://data.eastmoney.com/'
      });

      const resp: EastMoneyResponse = JSON.parse(raw);
      if (resp.success && resp.result && resp.result.data) {
        fullStockCache.clear();
        const dataItems = resp.result.data;
        for (let i = 0; i < dataItems.length; i++) {
          const item = dataItems[i];
          const code = String(item.SECURITY_CODE ?? '');
          const name = String(item.SECURITY_NAME_ABBR ?? '');
          if (code.length === 6 && name) {
            fullStockCache.set(code, name);
            fullStockCache.set(name, code);
          }
        }
        cacheLoaded = true;
        console.info('[StockSearch] 已加载 ' + (fullStockCache.size / 2) + ' 条股票数据');
      }
    } catch (e) {
      console.error('[StockSearch] 加载股票列表失败', e);
    }
  }

  private static async searchFromNetwork(kw: string): Promise<StockSearchItem[]> {
    try {
      const url = 'https://searchapi.eastmoney.com/api/suggest/get?input=' + encodeURIComponent(kw) + '&type=14&token=***&count=10';

      const raw = await HttpUtil.get(url, {
        'Referer': 'https://www.eastmoney.com/'
      });

      const resp: SuggestResponse = JSON.parse(raw);
      const stocks = resp.QuotationCodeTable?.Data ?? [];
      const filtered: StockSearchItem[] = [];
      for (let i = 0; i < stocks.length; i++) {
        const s = stocks[i];
        if (s.Code.length === 6) {
          filtered.push({
            code: s.Code,
            name: s.Name,
            market: s.Code.startsWith('6') || s.Code.startsWith('5') ? 'sh' : 'sz'
          });
        }
      }
      return filtered;
    } catch (e) {
      console.error('[StockSearch] 网络搜索失败', e);
      return [];
    }
  }

  static getStockName(code: string): string {
    const cached = fullStockCache.get(code);
    return CODE_TO_NAME[code] ?? cached ?? code;
  }
}
