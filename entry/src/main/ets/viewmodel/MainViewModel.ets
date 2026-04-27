/**
 * 主页面 ViewModel
 * 状态管理 + 业务逻辑
 */
import { StockInfo } from '../model/StockInfo';
import { DividendRecord, YearlyDividend } from '../model/DividendRecord';
import {
  DividendResult,
  StockBasicInfo,
  YearSummary,
  HistoricalComparison
} from '../model/DividendResult';
import { StockService } from '../service/StockService';
import { DividendService } from '../service/DividendService';
import { StockSearchService, StockSearchItem } from '../service/StockSearchService';

export class MainViewModel {
  // ====== 输入状态 ======
  stockCode: string = '';
  costPrice: number = 0;
  shares: number = 0;

  // ====== 输出状态 ======
  stockInfo: StockInfo | null = null;
  dividendResult: DividendResult | null = null;
  dividendRecords: DividendRecord[] = [];
  yearlyDividend: YearlyDividend | null = null;

  // ====== UI 状态 ======
  isLoading: boolean = false;
  errorMessage: string = '';

  // ====== 股票搜索状态 ======
  searchResults: StockSearchItem[] = [];
  isSearching: boolean = false;
  showSearchDropdown: boolean = false;

  // ====== 年份选择状态 ======
  availableYears: string[] = [];  // 可用年份列表 ['2025', '2024', '2023', '2022']
  selectedYear: string = '';       // 当前选中年份

  // ====== 计算当前年份字符串 ======
  private getCurrentYear(): string {
    return new Date().getFullYear().toString();
  }

  /**
   * 搜索股票（名称或代码）
   */
  async searchStocks(keyword: string): Promise<void> {
    if (!keyword || keyword.trim().length < 1) {
      this.searchResults = [];
      this.showSearchDropdown = false;
      return;
    }

    this.isSearching = true;
    try {
      const result = await StockSearchService.search(keyword.trim());
      this.searchResults = result.stocks;
      this.showSearchDropdown = result.stocks.length > 0;
    } catch (e) {
      console.error('[ViewModel] 搜索失败', e);
      this.searchResults = [];
      this.showSearchDropdown = false;
    } finally {
      this.isSearching = false;
    }
  }

  /**
   * 选中搜索结果
   */
  selectStock(code: string): void {
    this.stockCode = code;
    this.showSearchDropdown = false;
    this.searchResults = [];
  }

  /**
   * 隐藏搜索下拉
   */
  hideSearchDropdown(): void {
    this.showSearchDropdown = false;
  }

  /**
   * 选择年份
   */
  selectYear(year: string): void {
    if (this.selectedYear === year) return;
    this.selectedYear = year;
    // 重新构建当前选中年份的结果
    if (this.dividendRecords.length > 0 && this.stockInfo) {
      this.dividendResult = this.buildResult(year);
    }
  }

  /**
   * 执行计算
   */
  async calculate(): Promise<void> {
    // 参数校验
    if (!this.stockCode || this.stockCode.length !== 6) {
      this.errorMessage = '请输入正确的6位股票代码';
      return;
    }
    // 校验成本价格式：非空，且只含数字和小数点
    if (isNaN(this.costPrice) || this.costPrice <= 0) {
      this.errorMessage = '请输入有效的成本价（数字）';
      return;
    }
    if (this.shares <= 0) {
      this.errorMessage = '请输入持仓数量';
      return;
    }

    this.isLoading = true;
    this.errorMessage = '';
    this.hideSearchDropdown();

    try {
      console.info('[ViewModel] 开始计算，股票代码: ' + this.stockCode);

      // 1. 获取股票行情
      console.info('[ViewModel] 正在获取行情...');
      this.stockInfo = await StockService.getStockPrice(this.stockCode);
      console.info('[ViewModel] 行情结果: ' + JSON.stringify(this.stockInfo));

      if (!this.stockInfo) {
        this.errorMessage = '获取行情数据失败，请检查股票代码';
        return;
      }

      // 2. 获取分红数据
      console.info('[ViewModel] 正在获取分红数据...');
      this.dividendRecords = await DividendService.getDividendRecords(this.stockCode);
      console.info('[ViewModel] 分红记录数量: ' + this.dividendRecords.length);

      if (this.dividendRecords.length === 0) {
        // 股票无分红记录，但行情数据获取成功，兼容展示
        const result = new DividendResult();
        const stock = this.buildStockBasicInfo();
        result.stock = stock;
        result.year = this.getCurrentYear();
        result.noDividend = true;
        result.message = '该股票暂无分红记录';
        this.dividendResult = result;
        this.availableYears = [];
        return;
      }

      // 3. 确定可用年份
      this.availableYears = this.getAvailableYears();
      this.selectedYear = this.availableYears[0] ?? this.getCurrentYear();

      // 4. 构建完整结果
      this.dividendResult = this.buildResult(this.selectedYear);

    } catch (e) {
      console.error('[ViewModel] 计算异常', e);
      this.errorMessage = '计算异常: ' + e;
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 获取所有可用年份（2022-2025）
   */
  private getAvailableYears(): string[] {
    const years = ['2025', '2024', '2023', '2022'];
    const available: string[] = [];
    for (let i = 0; i < years.length; i++) {
      const y = years[i];
      const yearly = DividendService.getYearlyDividend(this.dividendRecords, y);
      if (yearly.details.length > 0) {
        available.push(y);
      }
    }
    return available;
  }

  /**
   * 构建 DividendResult
   */
  private buildResult(year: string): DividendResult {
    const result = new DividendResult();
    const stock = this.buildStockBasicInfo();
    result.stock = stock;
    result.year = year;

    // 计算所有年份的汇总数据
    result.allYearsSummary = this.buildAllYearsSummary();

    // 计算历史对比数据
    result.historicalComparison = this.buildHistoricalComparison();

    // 获取指定年份的分红数据
    this.yearlyDividend = DividendService.getYearlyDividend(this.dividendRecords, year);

    if (!this.yearlyDividend || this.yearlyDividend.details.length === 0) {
      result.noDividend = true;
      result.message = '暂无 ' + year + ' 年分红数据';
      return result;
    }

    result.yearlyPerShare = this.yearlyDividend.totalPerShare;
    result.totalDividend = Math.round(result.yearlyPerShare * this.shares * 100) / 100;
    result.yieldRateByCost = this.calcYieldRate(result.yearlyPerShare, this.costPrice);
    result.yieldRateByPrice = this.stockInfo?.prevClose
      ? this.calcYieldRate(result.yearlyPerShare, this.stockInfo.prevClose)
      : 0;
    result.details = this.yearlyDividend.details;
    result.isAnnounced = this.yearlyDividend.details.length > 0;
    result.isPaid = this.yearlyDividend.details.length > 0
      && this.yearlyDividend.details.every(d => d.isPaid);

    // 预计回收成本年限
    if (result.totalDividend > 0) {
      result.costRecoveryYears = Math.round((stock.totalCost / result.totalDividend) * 100) / 100;
    } else {
      result.costRecoveryYears = 0;
    }

    return result;
  }

  /**
   * 构建持仓基本信息
   */
  private buildStockBasicInfo(): StockBasicInfo {
    const stock = new StockBasicInfo();
    stock.code = this.stockCode;
    stock.name = this.stockInfo?.name ?? this.stockCode;
    stock.costPrice = this.costPrice;
    stock.shares = this.shares;
    stock.totalCost = this.costPrice * this.shares;
    stock.currentPrice = this.stockInfo?.current ?? 0;
    stock.prevClose = this.stockInfo?.prevClose ?? 0;
    stock.marketValue = stock.currentPrice * this.shares;
    stock.floatingPnL = (stock.currentPrice - this.costPrice) * this.shares;
    stock.floatingRate = this.costPrice > 0
      ? ((stock.currentPrice - this.costPrice) / this.costPrice) * 100
      : 0;
    return stock;
  }

  /**
   * 构建所有年份的分红汇总
   */
  private buildAllYearsSummary(): Record<string, YearSummary> {
    const summary: Record<string, YearSummary> = {};
    const years = ['2025', '2024', '2023', '2022'];

    for (let i = 0; i < years.length; i++) {
      const y = years[i];
      const yearly = DividendService.getYearlyDividend(this.dividendRecords, y);
      if (yearly.details.length > 0) {
        const s = new YearSummary();
        s.perShare = yearly.totalPerShare;
        s.totalDividend = Math.round(yearly.totalPerShare * this.shares * 100) / 100;
        s.yieldRate = this.calcYieldRate(yearly.totalPerShare, this.costPrice);
        s.hasDetail = yearly.details.length > 0;
        summary[y] = s;
      }
    }

    return summary;
  }

  /**
   * 构建历史年度对比数据
   */
  private buildHistoricalComparison(): HistoricalComparison[] {
    const historical: HistoricalComparison[] = [];
    const years = ['2024', '2023', '2022'];
    const prevClose = this.stockInfo?.prevClose ?? 0;

    for (let i = 0; i < years.length; i++) {
      const y = years[i];
      const yearly = DividendService.getYearlyDividend(this.dividendRecords, y);
      if (yearly.details.length > 0) {
        const h = new HistoricalComparison();
        h.year = y;
        h.perShare = yearly.totalPerShare;
        h.costYield = this.calcYieldRate(yearly.totalPerShare, this.costPrice);
        h.currentYield = prevClose > 0
          ? this.calcYieldRate(yearly.totalPerShare, prevClose)
          : 0;
        historical.push(h);
      }
    }

    return historical;
  }

  /**
   * 计算股息率
   */
  private calcYieldRate(dividendPerShare: number, price: number): number {
    if (price <= 0) {
      return 0;
    }
    return Math.round((dividendPerShare / price) * 10000) / 100; // 保留2位小数
  }

  /**
   * 重置
   */
  reset(): void {
    this.stockCode = '';
    this.costPrice = 0;
    this.shares = 0;
    this.stockInfo = null;
    this.dividendResult = null;
    this.dividendRecords = [];
    this.yearlyDividend = null;
    this.isLoading = false;
    this.errorMessage = '';
    this.searchResults = [];
    this.showSearchDropdown = false;
    this.availableYears = [];
    this.selectedYear = '';
  }
}
