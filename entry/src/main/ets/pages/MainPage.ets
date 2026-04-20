/**
 * 主页面
 * 股票分红计算器 - 输入股票代码、买入价、数量 → 计算分红收益
 */
import { DividendType } from '../model/DividendRecord';
import { DividendResult } from '../model/DividendResult';

/**
 * 格式化数字为千分位货币格式
 */
function formatCurrency(value: number): string {
  return value.toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

/**
 * 格式化百分比
 */
function formatPercent(value: number): string {
  return value.toFixed(2) + '%';
}

@Entry
@Component
struct MainPage {
  // ViewModel 通过 localStorage 或者 AppStorage 注入（此处简化为直接实例化）
  @State private viewModel: MainViewModel = new MainViewModel();
  // 输入框的值（单独管理以便 TwoWay 绑定）
  @State private inputCode: string = '';
  @State private inputCost: string = '';
  @State private inputShares: string = '';

  build() {
    Column() {
      // ====== 标题 ======
      Text('股票分红计算器')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 20 })

      // ====== 输入区域 ======
      Column() {
        TextInput({ placeholder: '股票代码（如 601318）', text: this.inputCode })
          .width('100%')
          .height(44)
          .fontSize(16)
          .inputMode(InputMode.Numeric)
          .maxLength(6)
          .onChange((v) => {
            this.inputCode = v;
            this.viewModel.stockCode = v;
          })

        TextInput({ placeholder: '成本价（元）', text: this.inputCost })
          .width('100%')
          .height(44)
          .fontSize(16)
          .inputMode(InputMode.Numeric)
          .type(InputType.Number)
          .onChange((v) => {
            this.inputCost = v;
            this.viewModel.costPrice = parseFloat(v) || 0;
          })

        TextInput({ placeholder: '持仓数量（股）', text: this.inputShares })
          .width('100%')
          .height(44)
          .fontSize(16)
          .inputMode(InputMode.Numeric)
          .type(InputType.Number)
          .onChange((v) => {
            this.inputShares = v;
            this.viewModel.shares = parseInt(v) || 0;
          })

        Button('开始计算')
          .width('100%')
          .height(48)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .margin({ top: 16 })
          .enabled(!this.viewModel.isLoading)
          .onClick(() => {
            this.viewModel.calculate();
          })
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#F5F5F5')
      .borderRadius(12)
      .margin({ bottom: 20 })

      // ====== 加载中 ======
      if (this.viewModel.isLoading) {
        LoadingProgress()
          .width(48)
          .height(48)
          .margin({ top: 40 })
      }

      // ====== 错误提示 ======
      if (this.viewModel.errorMessage) {
        Text(this.viewModel.errorMessage)
          .fontColor('#FF4444')
          .fontSize(14)
          .margin({ top: 10 })
      }

      // ====== 结果展示 ======
      if (this.viewModel.dividendResult) {
        this.ResultSection(this.viewModel.dividendResult)
      }
    }
    .width('100%')
    .height('100%')
    .padding(20)
    .backgroundColor('#FFFFFF')
  }

  @Builder
  ResultSection(result: DividendResult) {
    Column() {
      // ---- 股票行情卡片 ----
      Column() {
        Row() {
          Text(result.stock.name)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
          Text(` (${result.stock.code})`)
            .fontSize(16)
            .fontColor('#666666')
        }

        Row() {
          Column() {
            Text('昨收').fontSize(12).fontColor('#999999')
            Text(formatCurrency(result.stock.prevClose) + ' 元').fontSize(14)
          }.layoutWeight(1)

          Column() {
            Text('当前').fontSize(12).fontColor('#999999')
            Text(formatCurrency(result.stock.currentPrice) + ' 元').fontSize(14)
          }.layoutWeight(1)
        }
        .margin({ top: 8 })

        Row() {
          Column() {
            Text('持仓成本').fontSize(12).fontColor('#999999')
            Text(formatCurrency(result.stock.totalCost) + ' 元').fontSize(14)
          }.layoutWeight(1)

          Column() {
            Text('市值').fontSize(12).fontColor('#999999')
            Text(formatCurrency(result.stock.marketValue) + ' 元').fontSize(14)
          }.layoutWeight(1)
        }
        .margin({ top: 8 })

        Row() {
          Text('浮盈/亏: ')
            .fontSize(14)
            .fontColor('#999999')
          Text(formatCurrency(result.stock.floatingPnL) + ' 元')
            .fontSize(14)
            .fontColor(result.stock.floatingPnL >= 0 ? '#FF6B6B' : '#4CAF50')
          Text(` (${result.stock.floatingRate >= 0 ? '+' : ''}${formatPercent(result.stock.floatingRate)})`)
            .fontSize(14)
            .fontColor(result.stock.floatingPnL >= 0 ? '#FF6B6B' : '#4CAF50')
        }
        .margin({ top: 8 })
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#F0F8FF')
      .borderRadius(12)
      .margin({ bottom: 16 })

      // ---- 分红结果卡片 ----
      Column() {
        Row() {
          Text('💰 ')
            .fontSize(18)
          Text(`${result.year}年度分红`)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
        }

        Divider().margin({ top: 12, bottom: 12 })

        // 分红明细
        ForEach(result.details, (detail: any) => {
          Row() {
            Text(detail.type === DividendType.MidYear ? '中报' : '年报')
              .fontSize(14)
              .width(60)
            Text(detail.desc)
              .fontSize(14)
              .flexGrow(1)
            Text(detail.perShare.toFixed(4) + ' 元')
              .fontSize(14)
              .fontColor('#333333')
            Text(detail.isPaid ? '✅' : '⚠️')
              .fontSize(14)
              .margin({ left: 8 })
          }
          .width('100%')
          .margin({ bottom: 6 })
        })

        Divider().margin({ top: 8, bottom: 8 })

        // 合计
        Row() {
          Text('全年每股合计:')
            .fontSize(14)
            .fontColor('#666666')
          Text(result.yearlyPerShare.toFixed(4) + ' 元')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .margin({ left: 8 })
        }
        .width('100%')

        Divider().margin({ top: 12, bottom: 12 })

        // 关键数据
        Row() {
          Column() {
            Text('持股分红')
              .fontSize(12)
              .fontColor('#999999')
            Text('💵 ' + formatCurrency(result.totalDividend) + ' 元')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FF6B6B')
          }.layoutWeight(1)

          Column() {
            Text('股息率(成本)')
              .fontSize(12)
              .fontColor('#999999')
            Text('📊 ' + formatPercent(result.yieldRateByCost))
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FF6B6B')
          }.layoutWeight(1)

          Column() {
            Text('股息率(昨收)')
              .fontSize(12)
              .fontColor('#999999')
            Text('📊 ' + formatPercent(result.yieldRateByPrice))
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
          }.layoutWeight(1)
        }
        .width('100%')
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#FFF8F0')
      .borderRadius(12)
      .margin({ bottom: 16 })

      // ---- 历史分红记录 ----
      Column() {
        Row() {
          Text('📋 历史分红记录')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
        }

        Column() {
          ForEach(this.viewModel.dividendRecords.slice(0, 10), (record: any) => {
            Row() {
              Text(`${record.payYear || '-'} ${record.type}`)
                .fontSize(13)
                .width(80)
              Text(record.desc || '(无描述)')
                .fontSize(13)
                .flexGrow(1)
              Text(record.perShare > 0 ? record.perShare.toFixed(4) + ' 元' : '-')
                .fontSize(13)
                .fontColor(record.perShare > 0 ? '#333333' : '#999999')
            }
            .width('100%')
            .margin({ bottom: 8 })
          })
        }
        .margin({ top: 12 })
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#F9F9F9')
      .borderRadius(12)
    }
  }
}

// 导入
import prompt from '@ohos.prompt';
import { MainViewModel } from '../viewmodel/MainViewModel';
