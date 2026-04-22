# 股票分红计算器 Web Demo 设计文档

**日期**: 2026-04-22
**版本**: v1.0
**状态**: 已确认

---

## 1. 项目概述

**项目名称**: 股票分红计算器 Web Demo
**项目类型**: Flask 后端 + 简约现代风前端
**核心功能**: 输入股票代码和持仓信息，计算分红收益、股息率、预计回收成本时间
**目标用户**: A 股个人投资者

---

## 2. 技术架构

### 2.1 技术选型

| 层级 | 技术方案 |
|------|----------|
| 后端框架 | Flask |
| 后端逻辑 | 复用 `stock_api.py` + `dividend_calculator.py` |
| 前端 | 原生 HTML/CSS/JS（单文件） |
| 数据源 | 新浪财经（行情）+ 东方财富（分红） |

### 2.2 项目结构

```
stock-dividend-calculator/
├── app.py                      # Flask 主应用
├── templates/
│   └── index.html              # 前端页面
├── stock_api.py                # [复用] 股票数据接口
├── dividend_calculator.py       # [复用] 分红计算核心
├── requirements.txt            # 依赖（Flask + requests）
└── docs/
    └── superpowers/
        └── specs/
            └── 2026-04-22-stock-dividend-web-design.md
```

---

## 3. 功能规格

### 3.1 输入参数

| 字段 | 类型 | 说明 | 示例 |
|------|------|------|------|
| stock_code | string | 股票代码（6位数字） | "601318" |
| cost_price | float | 持仓成本价（元） | 21.423 |
| shares | int | 持股数量（股） | 1000 |

### 3.2 输出结果

| 字段 | 说明 | 计算公式 |
|------|------|----------|
| stock_name | 股票名称 | - |
| prev_close | 当日收盘价（昨收） | - |
| cost_yield_rate | 成本价股息率（%） | 全年每股分红 ÷ 成本价 × 100% |
| current_yield_rate | 当前价股息率（%） | 全年每股分红 ÷ 收盘价 × 100% |
| per_share_dividend | 每股分红（元） | - |
| yearly_total_dividend | 年度总分红（元） | 每股分红 × 股数 |
| cost_recovery_years | 预计回收成本（年） | 总成本 ÷ 年度总分红 |
| yearly_details | 年度分红明细 | 含每期中报/年报分红详情 |
| historical_comparison | 历史年度对比 | 2024/2023/2022 股息率对比 |

### 3.3 API 接口

**GET /api/dividend**

**请求参数**:
```
?code=601318&cost_price=21.423&shares=1000
```

**响应**:
```json
{
  "success": true,
  "data": {
    "stock_name": "中国平安",
    "prev_close": 45.23,
    "cost_yield_rate": 8.52,
    "current_yield_rate": 3.58,
    "per_share_dividend": 1.825,
    "yearly_total_dividend": 1825.00,
    "cost_recovery_years": 11.74,
    "yearly_details": [...],
    "historical_comparison": [
      {"year": "2024", "per_share": 1.58, "cost_yield": 7.37, "current_yield": 3.10},
      {"year": "2023", "per_share": 1.50, "cost_yield": 7.00, "current_yield": 2.95},
      {"year": "2022", "per_share": 1.28, "cost_yield": 5.97, "current_yield": 2.53}
    ]
  },
  "error": null
}
```

---

## 4. UI 设计规格

### 4.1 视觉风格

- **设计语言**: Apple 简约风
- **背景色**: 浅灰 #F5F5F7
- **卡片色**: 白色 #FFFFFF
- **圆角**: 12px
- **阴影**: 轻柔阴影 (0 2px 8px rgba(0,0,0,0.08))

### 4.2 配色方案

| 用途 | 颜色 | 色值 |
|------|------|------|
| 主色调 | Blue | #007AFF |
| 正向/已派息 | Green | #34C759 |
| 待派息 | Orange | #FF9500 |
| 文字主色 | Charcoal | #1D1D1F |
| 文字次色 | Gray | #86868B |
| 背景色 | Light Gray | #F5F5F7 |

### 4.3 布局结构

```
┌─────────────────────────────────────────────────┐
│  Header: 股票分红计算器                            │
├─────────────────────┬───────────────────────────┤
│                     │                           │
│   持仓信息卡片        │    分红结果卡片             │
│   - 股票代码输入      │    - 股票名称 + 收盘价       │
│   - 成本价输入       │    - 成本/当前价股息率       │
│   - 股数输入         │    - 每股/年度总分红         │
│   - [计算分红]       │    - 预计回收成本           │
│                     │    - 明细列表               │
│                     │                           │
├─────────────────────┴───────────────────────────┤
│                                                 │
│   历史年度对比表格 (2024 / 2023 / 2022)           │
│                                                 │
└─────────────────────────────────────────────────┘
```

### 4.4 响应式断点

| 屏幕宽度 | 布局 |
|----------|------|
| >= 768px | 双列卡片布局 |
| < 768px | 单列堆叠布局 |

---

## 5. 验收标准

1. 输入股票代码（601318）、成本价（21.423）、股数（1000）能正确返回分红数据
2. 成本价股息率和当前价股息率同时显示
3. 预计回收成本时间计算正确
4. 历史年度对比表格显示 2024/2023/2022 三年数据
5. 界面符合 Apple 简约风格，浅灰背景 + 白色圆角卡片
6. 移动端适配（响应式布局）
7. 网络错误时显示友好提示

---

## 6. 待实现

- [ ] 创建 `app.py` Flask 应用
- [ ] 创建 `templates/index.html` 前端页面
- [ ] 复用 `stock_api.py` 和 `dividend_calculator.py`
- [ ] 实现 `/api/dividend` 接口
- [ ] 实现前端 UI 和交互逻辑
- [ ] 测试验证功能正确性
