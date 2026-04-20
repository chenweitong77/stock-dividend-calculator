# 鸿蒙 App 技术方案 - 股票分红收益计算器

## 1. 项目概述

### 1.1 功能需求

- 用户输入股票代码、买入成本价、持仓数量
- 自动抓取该股当年分红数据（中报 + 年报）
- 计算股息率、当年分红金额、持仓盈亏
- 展示历史分红记录

### 1.2 数据接口（已验证）

| 数据 | 来源 | 接口 |
|------|------|------|
| 实时股价 | 新浪财经 | `https://hq.sinajs.cn/list=sh600519` |
| 分红数据 | 东方财富 | `https://datacenter-web.eastmoney.com/api/data/v1/get?reportName=RPT_LICO_FN_CPD` |

### 1.3 技术栈

- **框架**：HarmonyOS API 9+ / ArkTS
- **UI**：ArkUI 声明式开发框架
- **架构**：MVVM
- **网络**：@ohos.net.http

---

## 2. 应用架构

```
┌─────────────────────────────────────────────────────────────┐
│                        EntryAbility                         │
│  (应用入口，生命周期管理)                                    │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│                      MainViewModel                          │
│  (主页面 ViewModel，状态管理)                               │
│  - stockCode: string                                      │
│  - costPrice: number                                      │
│  - shares: number                                         │
│  - stockInfo: StockInfo | null                            │
│  - dividendResult: DividendResult | null                   │
│  - isLoading: boolean                                     │
└──────────────────────────┬──────────────────────────────────┘
                           │
          ┌────────────────┴────────────────┐
          │                                 │
┌─────────▼──────────┐           ┌─────────▼──────────┐
│    StockService    │           │  DividendService   │
│   (行情数据服务)    │           │   (分红数据服务)     │
│  调用新浪财经接口   │           │  调用东方财富接口    │
└─────────┬──────────┘           └─────────┬──────────┘
          │                                 │
          └──────────────┬──────────────────┘
                         │
              ┌──────────▼──────────┐
              │    DividendCalculator │
              │    (分红计算逻辑)     │
              │  按PAYYEAR归类年度分红│
              └─────────────────────┘
```

---

## 3. 项目目录结构

```
entry/src/main/ets/
├── entryability/
│   └── EntryAbility.ets           # 应用入口
│
├── view/
│   ├── MainPage.ets               # 主页面
│   ├── StockCard.ets              # 股票行情卡片
│   ├── DividendCard.ets            # 分红结果卡片
│   ├── DividendHistoryList.ets     # 历史分红列表
│   └── DividendHistoryItem.ets     # 历史分红单项
│
├── viewmodel/
│   └── MainViewModel.ets          # 主页面状态管理
│
├── model/
│   ├── StockInfo.ets               # 股票行情数据模型
│   ├── DividendRecord.ets          # 分红记录数据模型
│   └── DividendResult.ets          # 分红计算结果模型
│
├── service/
│   ├── StockService.ets            # 股票行情服务
│   └── DividendService.ets          # 分红数据服务
│
├── util/
│   ├── HttpUtil.ets                # HTTP 请求工具
│   └── StringUtil.ets               # 字符串处理工具
│
└── pages/
    └── Index.ets                   # 页面入口（由entryability启动）
```

---

## 4. 数据模型

### 4.1 StockInfo（股票行情）

```typescript
// 来自新浪财经接口
struct StockInfo {
  code: string           // 股票代码 "601318"
  name: string           // 股票名称 "中国平安"
  open: number           // 开盘价
  prevClose: number      // 昨收价
  current: number        // 当前价
  high: number           // 最高价
  low: number            // 最低价
}
```

### 4.2 DividendRecord（分红记录）

```typescript
// 来自东方财富 RPT_LICO_FN_CPD 接口
struct DividendRecord {
  payYear: string        // 利润归属年度 "2025"
  noticeDate: string     // 公告日期 "2025-03-20"
  exDate: string         // 除权除息日 "2025-03-19"
  desc: string           // 分红描述 "10派16.20元(含税)"
  perShare: number       // 每股派息 1.62
  isPaid: boolean        // 是否已派息
  type: DividendType     // 分红类型: 中报/年报
}

enum DividendType {
  MidYear = "中报",
  FullYear = "年报",
  Other = "其他"
}
```

### 4.3 DividendResult（计算结果）

```typescript
// App 需要展示给用户的完整结果
struct DividendResult {
  stock: StockBasicInfo
  year: string
  yearlyPerShare: number        // 全年每股合计分红
  totalDividend: number         // 用户持股总分红
  yieldRateByCost: number       // 股息率(成本价)
  yieldRateByPrice: number       // 股息率(昨收价)
  details: DividendRecord[]      // 分红明细
  isAnnounced: boolean           // 年报是否已公告
}

struct StockBasicInfo {
  code: string
  name: string
  costPrice: number
  shares: number
  totalCost: number
  currentPrice: number
  marketValue: number
  floatingPnL: number
  floatingRate: number
}
```

---

## 5. 核心算法

### 5.1 按 PAYYEAR 归类年度分红

```typescript
// dividend_calculator.ets

function getYearlyDividend(records: DividendRecord[], year: string): YearlyDividend {
  let yearlyPerShare = 0
  let hasMidYear = false
  let hasFullYear = false

  const details: DividendRecord[] = records.filter(record => {
    if (record.payYear !== year || !record.desc) {
      return false
    }
    // 解析每股派息
    const perShare = parseDividendPerShare(record.desc)
    if (perShare <= 0) {
      return false
    }
    record.perShare = perShare
    yearlyPerShare += perShare

    // 判断是中报还是年报
    if (isMidYear(record.noticeDate)) {
      hasMidYear = true
    } else if (isFullYear(record.noticeDate)) {
      hasFullYear = true
    }
    return true
  })

  return {
    year,
    yearlyPerShare,
    details,
    hasMidYear,
    hasFullYear
  }
}
```

### 5.2 计算股息率

```typescript
function calcYieldRate(dividendPerShare: number, costPrice: number): number {
  if (costPrice <= 0) {
    return 0
  }
  return (dividendPerShare / costPrice) * 100
}
```

### 5.3 解析每股派息

```typescript
// 从 "10派276.73元(含税,扣税后249.057元)" 提取 27.673
function parseDividendPerShare(desc: string): number {
  const match = desc.match(/(\d+)派([\d.]+)元/)
  if (match) {
    return parseFloat(match[2]) / parseInt(match[1])
  }
  return 0
}
```

---

## 6. HTTP 服务层

### 6.1 新浪财经股价接口

```typescript
// StockService.ets

async function getStockPrice(code: string): Promise<StockInfo | null> {
  const prefix = code.startsWith("6") ? "sh" : "sz"
  const url = `https://hq.sinajs.cn/list=${prefix}${code}`

  const response = await httpRequest.get(url, {
    header: {
      "Referer": "https://finance.sina.com.cn"
    }
  })

  // 解析: var hq_str_sh600519="贵州茅台,现价,昨收,开盘,最高,最低,..."
  const text = response.replace(/^[^"]+"|"$/g, '')
  const fields = text.split(',')

  return {
    code: code,
    name: fields[0].trim(),
    open: parseFloat(fields[1]),
    prevClose: parseFloat(fields[2]),
    current: parseFloat(fields[3]),
    high: parseFloat(fields[4]),
    low: parseFloat(fields[5])
  }
}
```

### 6.2 东方财富分红接口

```typescript
// DividendService.ets

async function getDividendRecords(code: string): Promise<DividendRecord[]> {
  const url = `https://datacenter-web.eastmoney.com/api/data/v1/get?` +
    `reportName=RPT_LICO_FN_CPD&` +
    `columns=SECURITY_CODE,SECURITY_NAME_ABBR,REPORTDATE,ASSIGNDSCRPT,PAYYEAR,ZXGXL,NOTICE_DATE,EITIME&` +
    `filter=(SECURITY_CODE%3D%22${code}%22)&` +
    `pageNumber=1&pageSize=20&source=WEB&client=WEB`

  const response = await httpRequest.get(url, {
    header: {
      "Referer": "https://data.eastmoney.com/"
    }
  })

  const result = JSON.parse(response)
  if (!result.success || !result.result) {
    return []
  }

  return result.result.data.map((item: any) => ({
    payYear: item.PAYYEAR || '',
    noticeDate: item.NOTICE_DATE || '',
    exDate: item.EITIME || '',
    desc: item.ASSIGNDSCRPT || '',
    perShare: 0,
    isPaid: checkIfPaid(item.EITIME),
    type: detectDividendType(item.NOTICE_DATE)
  }))
}
```

---

## 7. 页面设计

### 7.1 主页面布局

```
┌─────────────────────────────────────┐
│  股票分红计算器                      │
├─────────────────────────────────────┤
│  ┌─────────────────────────────┐    │
│  │ 股票代码  [601318    ] 🔍  │    │
│  │ 成本价    [21.423   ] 元   │    │
│  │ 持仓数量  [1000     ] 股   │    │
│  │                             │    │
│  │    [开始计算]               │    │
│  └─────────────────────────────┘    │
├─────────────────────────────────────┤
│  📈 中国平安 (601318)               │
│  昨收: 57.920 │ 当前: 58.540       │
│  持仓成本: 21,423.00 │ 市值: 58,540│
│  浮盈: +37,117.00 (+173.26%)       │
├─────────────────────────────────────┤
│  💰 2025年度分红                    │
│  ├─ 中报   10派9.50 → 0.95元 ✅   │
│  └─ 年报   10派17.50→ 1.75元 ⚠️   │
│  ─────────────────────────────────  │
│  每股合计: 2.70 元                  │
│  💵 持股分红: 2,700.00 元          │
│  📊 股息率: 12.60%                 │
├─────────────────────────────────────┤
│  📋 历史分红记录                    │
│  2024年报  10派16.20 → 1.62元     │
│  2024中报  10派9.30  → 0.93元     │
│  2023年报  10派15.00 → 1.50元     │
└─────────────────────────────────────┘
```

### 7.2 ArkUI 代码示例

```typescript
// MainPage.ets
@Entry
@Component
struct MainPage {
  @State viewModel: MainViewModel = new MainViewModel()

  build() {
    Column() {
      // 输入区域
      this.InputSection()

      // 加载指示器
      if (this.viewModel.isLoading) {
        LoadingProgress()
          .width(50)
          .height(50)
      }

      // 结果区域
      if (this.viewModel.dividendResult) {
        this.ResultSection()
      }
    }
    .padding(20)
    .width('100%')
    .height('100%')
  }

  @Builder
  InputSection() {
    Column() {
      TextInput({ placeholder: '股票代码', text: this.viewModel.stockCode })
        .onChange(v => this.viewModel.stockCode = v)

      TextInput({ placeholder: '成本价', text: this.viewModel.costPrice.toString() })
        .onChange(v => this.viewModel.costPrice = parseFloat(v))

      TextInput({ placeholder: '持仓数量', text: this.viewModel.shares.toString() })
        .onChange(v => this.viewModel.shares = parseInt(v))

      Button('开始计算')
        .onClick(() => this.viewModel.calculate())
    }
  }

  @Builder
  ResultSection() {
    Column() {
      // 股票信息卡片
      StockCard({ info: this.viewModel.stockInfo })

      // 分红结果卡片
      DividendCard({ result: this.viewModel.dividendResult })

      // 历史记录
      DividendHistoryList({ records: this.viewModel.dividendRecords })
    }
  }
}
```

---

## 8. 状态管理

```typescript
// MainViewModel.ets
class MainViewModel {
  // 输入状态
  stockCode: string = ''
  costPrice: number = 0
  shares: number = 0

  // 输出状态
  stockInfo: StockInfo | null = null
  dividendResult: DividendResult | null = null
  dividendRecords: DividendRecord[] = []
  isLoading: boolean = false

  async calculate() {
    if (!this.stockCode || this.costPrice <= 0 || this.shares <= 0) {
      return
    }

    this.isLoading = true

    try {
      // 1. 获取行情数据
      this.stockInfo = await StockService.getStockPrice(this.stockCode)

      // 2. 获取分红数据
      const records = await DividendService.getDividendRecords(this.stockCode)

      // 3. 计算当前年份分红
      const currentYear = new Date().getFullYear().toString()
      const yearlyDiv = DividendCalculator.getYearlyDividend(records, currentYear)

      // 4. 构建结果
      this.dividendResult = DividendCalculator.buildResult(
        this.stockCode,
        this.stockInfo,
        this.costPrice,
        this.shares,
        yearlyDiv,
        currentYear
      )

      this.dividendRecords = records

    } catch (e) {
      // 错误处理
    } finally {
      this.isLoading = false
    }
  }
}
```

---

## 9. 依赖与配置

### 9.1 权限配置

```json
// module.json5
{
  "module": {
    "requestPermissions": [
      {
        "name": "ohos.permission.INTERNET"
      }
    ]
  }
}
```

### 9.2 依赖

```json
// oh-package.json5
{
  "dependencies": {
    "@ohos/http": "file:../http"
  }
}
```

---

## 10. 开发计划

| 阶段 | 任务 | 优先级 |
|------|------|--------|
| Phase 1 | 项目搭建、HTTP 工具类、网络权限 | P0 |
| Phase 2 | 数据模型定义 | P0 |
| Phase 3 | StockService、DividendService 实现 | P0 |
| Phase 4 | MainViewModel 状态管理 | P0 |
| Phase 5 | 主页面 UI（输入+计算按钮） | P0 |
| Phase 6 | StockCard、DividendCard 组件 | P1 |
| Phase 7 | 历史分红列表 | P1 |
| Phase 8 | 华为真机调试 | P1 |
| Phase 9 | 上架应用市场 | P2 |

---

## 11. 注意事项

1. **网络请求**：鸿蒙 App 使用 `@ohos.net.http`，注意异步处理
2. **股票代码**：上海以 6 开头，深圳以 0 开头
3. **分红归类**：必须按 PAYYEAR（利润归属年度）归类，而非派息日期
4. **除权除息**：已公告但未到派息日的分红，应标注"待派息"
5. **容错处理**：接口可能失败，需做好异常处理
