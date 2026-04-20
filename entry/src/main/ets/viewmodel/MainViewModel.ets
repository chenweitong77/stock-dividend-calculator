/**
 * 主页面 ViewModel
 * 状态管理 + 业务逻辑
 */
import { StockInfo } from '../model/StockInfo';
import { DividendRecord, YearlyDividend } from '../model/DividendRecord';
import { DividendResult, StockBasicInfo } from '../model/DividendResult';
import { StockService } from '../service/StockService';
import { DividendService } from '../service/DividendService';

/**
 * 计算当前年份字符串
 */
function getCurrentYear(): string {
  return new Date().getFullYear().toString();
}

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

  /**
   * 执行计算
   */
  async calculate(): Promise<void> {
    // 参数校验
    if (!this.stockCode || this.stockCode.length !== 6) {
      this.errorMessage = '请输入正确的6位股票代码';
      return;
    }
    if (this.costPrice <= 0) {
      this.errorMessage = '请输入成本价';
      return;
    }
    if (this.shares <= 0) {
      this.errorMessage = '请输入持仓数量';
      return;
    }

    this.isLoading = true;
    this.errorMessage = '';

    try {
      // 1. 获取股票行情
      this.stockInfo = await StockService.getStockPrice(this.stockCode);

      // 2. 获取分红数据
      this.dividendRecords = await DividendService.getDividendRecords(this.stockCode);

      if (!this.stockInfo || this.dividendRecords.length === 0) {
        this.errorMessage = '获取数据失败，请检查股票代码';
        return;
      }

      // 3. 计算当前年度分红
      const currentYear = getCurrentYear();
      this.yearlyDividend = DividendService.getYearlyDividend(this.dividendRecords, currentYear);

      // 4. 构建完整结果
      this.dividendResult = this.buildResult(currentYear);

    } catch (e) {
      this.errorMessage = `计算异常: ${e}`;
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 构建 DividendResult
   */
  private buildResult(year: string): DividendResult {
    const result = new DividendResult();

    // 持仓信息
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

    result.stock = stock;

    // 分红信息
    result.year = year;
    result.yearlyPerShare = this.yearlyDividend?.totalPerShare ?? 0;
    result.totalDividend = Math.round(result.yearlyPerShare * this.shares * 100) / 100;
    result.yieldRateByCost = this.calcYieldRate(result.yearlyPerShare, this.costPrice);
    result.yieldRateByPrice = this.stockInfo?.prevClose
      ? this.calcYieldRate(result.yearlyPerShare, this.stockInfo.prevClose)
      : 0;
    result.details = this.yearlyDividend?.details ?? [];
    result.isAnnounced = this.yearlyDividend?.hasFullYear ?? false;

    return result;
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
  }
}
