# 股票分红计算器

鸿蒙 App「股票分红收益计算器」的数据接口与计算逻辑 Python 实现。

## 功能

- 获取 A 股实时行情（股价、开盘价、最高、最低价）
- 获取 A 股历史分红记录（东方财富 RPT_LICO_FN_CPD 接口）
- 计算用户持仓的分红收益与股息率
- 支持按利润归属年度（PAYYEAR）累加全年分红

## 数据接口

| 数据 | 来源 | 接口 |
|------|------|------|
| 实时股价 | 新浪财经 | `hq.sinajs.cn` |
| 分红数据 | 东方财富 | `datacenter-web.eastmoney.com/api/data/v1/get?reportName=RPT_LICO_FN_CPD` |

## 安装

```bash
pip install requests
```

## 使用方法

```bash
python main.py
```

## 项目结构

```
stock-dividend-calculator/
├── README.md
├── requirements.txt
├── stock_api.py          # 数据获取接口
├── dividend_calculator.py # 分红计算逻辑
└── main.py               # 演示程序
```

## 股息率计算公式

```
股息率 = (中报每股派息 + 年报每股派息) / 成本价 × 100%
```

注意：分红按「利润归属年度（PAYYEAR）」归类，而非按派息日期归类。

## 示例

以中国平安（601318）为例：
- 成本价：21.423 元
- 持仓：1000 股
- 2025 年度分红：中报 0.95 元 + 年报 1.75 元 = 2.70 元
- 股息率：2.70 / 21.423 = 12.60%
- 当年分红：2700 元
