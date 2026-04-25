/**
 * 主页面
 * 股票分红计算器 - Apple 简约风格
 * 功能：输入股票代码/名称、成本价、持股数 → 计算分红收益、股息率、回收成本
 */
import prompt from '@ohos.prompt';
import { MainViewModel } from '../viewmodel/MainViewModel';
import { DividendType } from '../model/DividendRecord';
import { StockSearchItem } from '../service/StockSearchService';

@Entry
@Component
struct MainPage {
  @State private viewModel: MainViewModel = new MainViewModel();
  // 输入框文本（单独状态便于 TwoWay 绑定）
  @State private inputCode: string = '';
  @State private inputCost: string = '';
  @State private inputShares: string = '';
  // 搜索下拉显隐
  @State private showDropdown: boolean = false;

  // ======== 工具方法 ========
  /**
   * 格式化货币（千分位，保留2位小数）
   */
  formatMoney(value: number): string {
    return value.toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  }

  /**
   * 格式化百分比（保留2位小数）
   */
  formatPercent(value: number): string {
    return value.toFixed(2) + '%';
  }

  // ======== 搜索相关 ========
  /**
   * 搜索防抖定时器
   */
  private searchTimer: number = -1;

  onCodeChange(value: string) {
    this.inputCode = value;
    this.viewModel.stockCode = value;

    // 清除上一个定时器
    if (this.searchTimer > 0) {
      clearTimeout(this.searchTimer);
    }

    if (value.length < 1) {
      this.showDropdown = false;
      this.viewModel.searchResults = [];
      return;
    }

    // 300ms 防抖
    this.searchTimer = setTimeout(() => {
      this.viewModel.searchStocks(value).then(() => {
        this.showDropdown = this.viewModel.showSearchDropdown;
      });
    }, 300) as number;
  }

  onCodeFocus(focused: boolean) {
    if (focused && this.viewModel.searchResults.length > 0) {
      this.showDropdown = true;
    }
  }

  selectSearchItem(item: StockSearchItem) {
    this.inputCode = item.code;
    this.viewModel.selectStock(item.code);
    this.showDropdown = false;
    this.viewModel.searchResults = [];
  }

  // ======== 页面 build ========
  build() {
    Column() {
      // ====== 标题 ======
      Text('股票分红计算器')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1D1D1F')
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ top: 16, bottom: 20 })

      Scroll() {
        Column({ space: 16 }) {
          // ====== 持仓信息卡片 ======
          this.InputCard()

          // ====== 分红结果卡片 ======
          if (this.viewModel.isLoading) {
            this.LoadingSection()
          } else if (this.viewModel.errorMessage) {
            this.ErrorSection()
          } else if (this.viewModel.dividendResult) {
            this.ResultCard()
          }

          // ====== 历史年度对比表格 ======
          if (this.viewModel.dividendResult &&
              this.viewModel.dividendResult.historicalComparison.length > 0) {
            this.HistoricalSection()
          }
        }
        .padding({ bottom: 32 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F7')
    .padding({ left: 16, right: 16 })
  }

  // ======== 输入卡片 ========
  @Builder
  InputCard() {
    Column({ space: 12 }) {
      // 股票代码（带搜索下拉）
      Column() {
        Text('股票代码 / 名称')
          .fontSize(12)
          .fontColor('#86868B')
          .width('100%')
          .padding({ left: 4, bottom: 6 })

        Stack({ alignContent: Alignment.TopStart }) {
          TextInput({ placeholder: '输入股票代码或名称，如 601318', text: this.inputCode })
            .width('100%')
            .height(44)
            .fontSize(16)
            .inputMode(InputMode.Numeric)
            .maxLength(10)
            .onChange((v: string) => this.onCodeChange(v))
            .onFocus((f: boolean) => this.onCodeFocus(f))

          // 搜索下拉
          if (this.showDropdown && this.viewModel.searchResults.length > 0) {
            Column() {
              ForEach(this.viewModel.searchResults, (item: StockSearchItem) => {
                Row() {
                  Column() {
                    Text(item.code)
                      .fontSize(14)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#1D1D1F')
                    Text(item.name)
                      .fontSize(12)
                      .fontColor('#86868B')
                      .margin({ top: 2 })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  Text(item.market === 'sh' ? '沪' : '深')
                    .fontSize(12)
                    .fontColor('#86868B')
                    .backgroundColor('#F0F0F0')
                    .borderRadius(4)
                    .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                }
                .width('100%')
                .padding(12)
                .onClick(() => this.selectSearchItem(item))
              })
            }
            .width('100%')
            .margin({ top: 44 })
            .backgroundColor('#FFFFFF')
            .borderRadius(8)
            .shadow({
              radius: 12,
              color: 'rgba(0,0,0,0.15)',
              offsetX: 0,
              offsetY: 4
            })
          }
        }
        .width('100%')
      }

      // 成本价
      Column() {
        Text('成本价（元）')
          .fontSize(12)
          .fontColor('#86868B')
          .width('100%')
          .padding({ left: 4, bottom: 6 })
        TextInput({ placeholder: '如 21.423', text: this.inputCost })
          .width('100%')
          .height(44)
          .fontSize(16)
          .inputMode(InputMode.Numeric)
          .type(InputType.Number)
          .onChange((v: string) => {
            this.inputCost = v;
            this.viewModel.costPrice = parseFloat(v) || 0;
          })
      }

      // 持股数量
      Column() {
        Text('持股数量（股）')
          .fontSize(12)
          .fontColor('#86868B')
          .width('100%')
          .padding({ left: 4, bottom: 6 })
        TextInput({ placeholder: '如 1000', text: this.inputShares })
          .width('100%')
          .height(44)
          .fontSize(16)
          .inputMode(InputMode.Numeric)
          .type(InputType.Number)
          .onChange((v: string) => {
            this.inputShares = v;
            this.viewModel.shares = parseInt(v) || 0;
          })
      }

      // 计算按钮
      Button('计算分红')
        .width('100%')
        .height(48)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .backgroundColor('#007AFF')
        .borderRadius(8)
        .enabled(!this.viewModel.isLoading)
        .onClick(() => {
          // 点击时隐藏键盘和下拉
          focusControl.getOrCreateFocusControlTuple().requestFocus(null);
          this.showDropdown = false;
          this.viewModel.calculate();
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .shadow({
      radius: 8,
      color: 'rgba(0,0,0,0.08)',
      offsetX: 0,
      offsetY: 2
    })
  }

  // ======== 加载中 ========
  @Builder
  LoadingSection() {
    Column() {
      LoadingProgress()
        .width(48)
        .height(48)
        .color('#007AFF')
      Text('计算中...')
        .fontSize(14)
        .fontColor('#86868B')
        .margin({ top: 12 })
    }
    .width('100%')
    .padding(40)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .shadow({
      radius: 8,
      color: 'rgba(0,0,0,0.08)',
      offsetX: 0,
      offsetY: 2
    })
  }

  // ======== 错误提示 ========
  @Builder
  ErrorSection() {
    Column() {
      Text('⚠️ ' + this.viewModel.errorMessage)
        .fontSize(14)
        .fontColor('#FF3B30')
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FF3B3020')
    .borderRadius(12)
  }

  // ======== 结果卡片 ========
  @Builder
  ResultCard() {
    Column({ space: 12 }) {
      // 股票名称 + 昨收
      Row() {
        Text(this.viewModel.dividendResult?.stock.name ?? '')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1D1D1F')
        Text(' (' + (this.viewModel.dividendResult?.stock.code ?? '') + ')')
          .fontSize(16)
          .fontColor('#86868B')
      }
      .width('100%')

      Text('昨收 ' + this.formatMoney(this.viewModel.dividendResult?.stock.prevClose ?? 0) + ' 元')
        .fontSize(13)
        .fontColor('#86868B')
        .width('100%')
        .margin({ top: 2 })

      Divider().color('#E5E5E5').margin({ top: 8, bottom: 4 })

      // 无分红记录
      if (this.viewModel.dividendResult?.noDividend) {
        Text(this.viewModel.dividendResult?.message ?? '暂无分红记录')
          .fontSize(14)
          .fontColor('#86868B')
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 20, bottom: 20 })
        return;
      }

      // 年份选择器（多个年份时显示）
      if (this.viewModel.availableYears.length > 1) {
        this.YearSelector()
      }

      // 指标网格（2x3 布局）
      this.MetricsGrid()

      // 分红明细
      if (this.viewModel.dividendResult?.details.length > 0) {
        Divider().color('#E5E5E5').margin({ top: 12, bottom: 8 })
        this.DividendDetails()
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .shadow({
      radius: 8,
      color: 'rgba(0,0,0,0.08)',
      offsetX: 0,
      offsetY: 2
    })
  }

  // ======== 年份选择器 ========
  @Builder
  YearSelector() {
    Row({ space: 8 }) {
      ForEach(this.viewModel.availableYears, (year: string) => {
        Button(year + '年')
          .fontSize(13)
          .height(32)
          .padding({ left: 14, right: 14 })
          .fontColor(this.viewModel.selectedYear === year ? '#FFFFFF' : '#007AFF')
          .backgroundColor(this.viewModel.selectedYear === year ? '#007AFF' : '#FFFFFF')
          .borderColor(this.viewModel.selectedYear === year ? '#007AFF' : '#E5E5E5')
          .borderWidth(1)
          .borderRadius(16)
          .onClick(() => {
            this.viewModel.selectYear(year);
          })
      })
    }
    .width('100%')
    .margin({ top: 4, bottom: 4 })
  }

  // ======== 指标网格 ========
  @Builder
  MetricsGrid() {
    Column() {
      // 第一行：股息率 x2
      Row({ space: 12 }) {
        this.MetricCard(
          '成本价股息率',
          this.formatPercent(this.viewModel.dividendResult?.yieldRateByCost ?? 0),
          '#1D1D1F'
        )
        this.MetricCard(
          '当前价股息率',
          this.formatPercent(this.viewModel.dividendResult?.yieldRateByPrice ?? 0),
          '#1D1D1F'
        )
      }

      Row({ space: 12 }) {
        this.MetricCard(
          '每股分红',
          this.formatMoney(this.viewModel.dividendResult?.yearlyPerShare ?? 0) + ' 元',
          '#1D1D1F'
        )
        this.MetricCard(
          '年度总分红',
          this.formatMoney(this.viewModel.dividendResult?.totalDividend ?? 0) + ' 元',
          '#007AFF'
        )
      }

      // 回收成本（占整行）
      this.MetricCardFull(
        '预计回收成本',
        (this.viewModel.dividendResult?.costRecoveryYears ?? 0).toFixed(1) + ' 年',
        '#007AFF'
      )
    }
  }

  @Builder
  MetricCard(label: string, value: string, valueColor: string) {
    Column() {
      Text(label)
        .fontSize(12)
        .fontColor('#86868B')
      Text(value)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(valueColor)
        .margin({ top: 4 })
    }
    .flexGrow(1)
    .padding(12)
    .backgroundColor('#F5F5F7')
    .borderRadius(8)
  }

  @Builder
  MetricCardFull(label: string, value: string, valueColor: string) {
    Row() {
      Text(label)
        .fontSize(12)
        .fontColor('#86868B')
      Text(value)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(valueColor)
        .margin({ left: 8 })
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#F5F5F7')
    .borderRadius(8)
  }

  // ======== 分红明细列表 ========
  @Builder
  DividendDetails() {
    Column() {
      Text('年度分红明细')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1D1D1F')
        .width('100%')
        .margin({ bottom: 8 })

      ForEach(this.viewModel.dividendResult?.details ?? [], (detail: any) => {
        Row() {
          // 分红类型标签
          Text(this.getTypeName(detail.type))
            .fontSize(12)
            .fontColor(detail.isPaid ? '#34C759' : '#FF9500')
            .backgroundColor(detail.isPaid ? '#34C75915' : '#FF950015')
            .borderRadius(4)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })

          Text(detail.desc || '')
            .fontSize(13)
            .fontColor('#333333')
            .flexGrow(1)
            .margin({ left: 8 })

          Column() {
            Text(detail.perShare.toFixed(4) + ' 元')
              .fontSize(13)
              .fontColor('#333333')
            Text(detail.isPaid ? '✓ 已派息' : '◐ 待派息')
              .fontSize(11)
              .fontColor(detail.isPaid ? '#34C759' : '#FF9500')
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.End)
        }
        .width('100%')
        .padding({ top: 8, bottom: 8 })
        .border({
          width: { bottom: 1 },
          color: '#F0F0F0'
        })
      })
    }
  }

  /**
   * 获取分红类型的中文名称
   */
  getTypeName(type: DividendType): string {
    switch (type) {
      case DividendType.Q1: return '一季报';
      case DividendType.MidYear: return '中报';
      case DividendType.Q3: return '三季报';
      case DividendType.FullYear: return '年报';
      default: return '其他';
    }
  }

  // ======== 历史年度对比表格 ========
  @Builder
  HistoricalSection() {
    Column({ space: 10 }) {
      Text('历史年度对比')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1D1D1F')
        .width('100%')
        .margin({ bottom: 4 })

      // 表头
      Row() {
        Text('年度')
          .fontSize(12)
          .fontColor('#86868B')
          .width(60)
        Text('每股分红')
          .fontSize(12)
          .fontColor('#86868B')
          .flexGrow(1)
        Text('成本价股息率')
          .fontSize(12)
          .fontColor('#86868B')
          .flexGrow(1)
          .textAlign(TextAlign.End)
        Text('当前价股息率')
          .fontSize(12)
          .fontColor('#86868B')
          .flexGrow(1)
          .textAlign(TextAlign.End)
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 10, bottom: 6 })

      Divider().color('#E5E5E5')

      // 数据行
      ForEach(this.viewModel.dividendResult?.historicalComparison ?? [], (h: any) => {
        Row() {
          Text(h.year + '年')
            .fontSize(14)
            .fontColor('#1D1D1F')
            .width(60)
          Text(h.perShare.toFixed(4) + ' 元')
            .fontSize(14)
            .fontColor('#333333')
            .flexGrow(1)
          Text(this.formatPercent(h.costYield))
            .fontSize(14)
            .fontColor('#FF6B6B')
            .flexGrow(1)
            .textAlign(TextAlign.End)
          Text(this.formatPercent(h.currentYield))
            .fontSize(14)
            .fontColor('#86868B')
            .flexGrow(1)
            .textAlign(TextAlign.End)
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        .border({
          width: { bottom: 1 },
          color: '#F0F0F0'
        })
      })
    }
    .width('100%')
    .padding(8)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .shadow({
      radius: 8,
      color: 'rgba(0,0,0,0.08)',
      offsetX: 0,
      offsetY: 2
    })
  }
}

// 获取焦点控制
import { focusControl } from '@ohos.ability.focusControl';
