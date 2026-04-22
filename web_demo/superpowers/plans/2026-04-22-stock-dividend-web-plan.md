# 股票分红计算器 Web Demo 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建一个 Flask 后端 + 简约现代风前端的股票分红计算器 Web Demo

**Architecture:** 采用 Flask 作为后端服务器，复用现有的 `stock_api.py` 和 `dividend_calculator.py`，前端使用原生 HTML/CSS/JS 单文件实现，通过 AJAX 调用后端 API 获取数据并渲染结果。

**Tech Stack:** Flask, Python, HTML/CSS/JS, 新浪财经 API, 东方财富 API

---

## 文件结构

```
stock-dividend-calculator/
├── app.py                      # [新建] Flask 主应用
├── templates/
│   └── index.html              # [新建] 前端页面
├── stock_api.py                # [复用] 股票数据接口
├── dividend_calculator.py       # [复用] 分红计算核心
└── requirements.txt            # [修改] 添加 Flask 依赖
```

---

## 实现任务

### Task 1: 创建 Flask 应用入口

**Files:**
- Create: `stock-dividend-calculator/app.py`
- Modify: `stock-dividend-calculator/requirements.txt`

- [ ] **Step 1: 添加 Flask 依赖到 requirements.txt**

```text
Flask>=2.3.0
requests>=2.25.0
```

- [ ] **Step 2: 创建 Flask 应用 app.py**

```python
# -*- coding: utf-8 -*-
"""
股票分红计算器 Web Demo - Flask 应用入口
"""

from flask import Flask, render_template, request, jsonify
from dividend_calculator import StockPosition, format_dividend_report
from stock_api import get_stock_info

app = Flask(__name__)


@app.route('/')
def index():
    """渲染前端页面"""
    return render_template('index.html')


@app.route('/api/dividend')
def api_dividend():
    """
    分红计算 API

    请求参数:
        code: 股票代码 (如 601318)
        cost_price: 成本价 (如 21.423)
        shares: 股数 (如 1000)
        year: 年份 (默认 2025)
    """
    code = request.args.get('code', '')
    cost_price = request.args.get('cost_price', type=float)
    shares = request.args.get('shares', type=int)
    year = request.args.get('year', '2025')

    if not code or not cost_price or not shares:
        return jsonify({
            'success': False,
            'data': None,
            'error': '缺少必要参数: code, cost_price, shares'
        })

    try:
        stock_info = get_stock_info(code)
        price_info = stock_info['price_info']
        dividend_records = stock_info['dividend_records']

        if not price_info:
            return jsonify({
                'success': False,
                'data': None,
                'error': '获取行情数据失败'
            })

        if not dividend_records:
            return jsonify({
                'success': False,
                'data': None,
                'error': '获取分红数据失败'
            })

        position = StockPosition(
            code=code,
            name=price_info.get('name', ''),
            cost_price=cost_price,
            shares=shares,
            current_price=price_info.get('current', 0),
            prev_close=price_info.get('prev_close', 0),
        )

        result = position.calc_dividend(dividend_records, year=year)

        historical = []
        for y in ['2024', '2023', '2022']:
            yearly = position.calc_dividend(dividend_records, year=y)
            if yearly['yearly_info']['detail']:
                historical.append({
                    'year': y,
                    'per_share': yearly['yearly_info']['total_per_share'],
                    'cost_yield': yearly['yield_rate'],
                    'current_yield': yearly['yield_rate'] * cost_price / price_info.get('prev_close', 1) if price_info.get('prev_close') else 0
                })

        return jsonify({
            'success': True,
            'data': {
                'stock_name': result['stock']['name'],
                'prev_close': result['stock']['prev_close'],
                'cost_yield_rate': result['yield_rate'],
                'current_yield_rate': result['yield_rate'] * cost_price / price_info.get('prev_close', 1) if price_info.get('prev_close') else 0,
                'per_share_dividend': result['yearly_info']['total_per_share'],
                'yearly_total_dividend': result['total_dividend'],
                'cost_recovery_years': round(result['stock']['total_cost'] / result['total_dividend'], 2) if result['total_dividend'] > 0 else 0,
                'yearly_details': result['yearly_info']['detail'],
                'historical_comparison': historical,
                'is_announced': result['yearly_info']['is_announced'],
                'is_paid': result['yearly_info']['is_paid'],
            },
            'error': None
        })

    except Exception as e:
        return jsonify({
            'success': False,
            'data': None,
            'error': str(e)
        })


if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
```

- [ ] **Step 3: 提交代码**

```bash
git add app.py requirements.txt
git commit -m "feat: add Flask application entry point"
```

---

### Task 2: 创建前端页面

**Files:**
- Create: `stock-dividend-calculator/templates/index.html`

- [ ] **Step 1: 创建 templates 目录**

```bash
mkdir -p stock-dividend-calculator/templates
```

- [ ] **Step 2: 创建前端页面 templates/index.html**

```html
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>股票分红计算器</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'PingFang SC', 'Microsoft YaHei', sans-serif;
            background-color: #F5F5F7;
            color: #1D1D1F;
            min-height: 100vh;
        }

        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }

        /* Header */
        header {
            background: #FFFFFF;
            padding: 20px 0;
            text-align: center;
            margin-bottom: 24px;
            border-radius: 12px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.08);
        }

        header h1 {
            font-size: 28px;
            font-weight: 600;
            color: #1D1D1F;
        }

        /* Main Layout */
        .main-content {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 24px;
            margin-bottom: 24px;
        }

        @media (max-width: 768px) {
            .main-content {
                grid-template-columns: 1fr;
            }
        }

        /* Cards */
        .card {
            background: #FFFFFF;
            border-radius: 12px;
            padding: 24px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.08);
        }

        .card-title {
            font-size: 18px;
            font-weight: 600;
            margin-bottom: 20px;
            color: #1D1D1F;
        }

        /* Form Elements */
        .form-group {
            margin-bottom: 16px;
        }

        .form-group label {
            display: block;
            font-size: 14px;
            color: #86868B;
            margin-bottom: 6px;
        }

        .form-group input {
            width: 100%;
            padding: 12px 16px;
            border: 1px solid #E5E5E5;
            border-radius: 8px;
            font-size: 16px;
            transition: border-color 0.2s;
        }

        .form-group input:focus {
            outline: none;
            border-color: #007AFF;
        }

        .btn-calculate {
            width: 100%;
            padding: 14px;
            background: #007AFF;
            color: #FFFFFF;
            border: none;
            border-radius: 8px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: background 0.2s;
        }

        .btn-calculate:hover {
            background: #0066D6;
        }

        .btn-calculate:disabled {
            background: #C5C5C7;
            cursor: not-allowed;
        }

        /* Result Display */
        .result-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 16px;
        }

        .stock-name {
            font-size: 20px;
            font-weight: 600;
        }

        .prev-close {
            font-size: 14px;
            color: #86868B;
        }

        .metrics-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 16px;
            margin-bottom: 20px;
        }

        .metric {
            background: #F5F5F7;
            padding: 16px;
            border-radius: 8px;
        }

        .metric-label {
            font-size: 12px;
            color: #86868B;
            margin-bottom: 4px;
        }

        .metric-value {
            font-size: 24px;
            font-weight: 600;
            color: #1D1D1F;
        }

        .metric-value.highlight {
            color: #007AFF;
        }

        .metric-unit {
            font-size: 14px;
            font-weight: normal;
            color: #86868B;
        }

        /* Dividend Details */
        .dividend-details {
            margin-top: 20px;
            padding-top: 20px;
            border-top: 1px solid #E5E5E5;
        }

        .detail-title {
            font-size: 14px;
            font-weight: 600;
            margin-bottom: 12px;
        }

        .detail-item {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 10px 0;
            border-bottom: 1px solid #F0F0F0;
        }

        .detail-item:last-child {
            border-bottom: none;
        }

        .detail-status {
            font-size: 12px;
            padding: 2px 8px;
            border-radius: 4px;
        }

        .status-paid {
            background: #34C75920;
            color: #34C759;
        }

        .status-pending {
            background: #FF950020;
            color: #FF9500;
        }

        /* Historical Table */
        .historical-section {
            background: #FFFFFF;
            border-radius: 12px;
            padding: 24px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.08);
        }

        .historical-title {
            font-size: 18px;
            font-weight: 600;
            margin-bottom: 16px;
        }

        .historical-table {
            width: 100%;
            border-collapse: collapse;
        }

        .historical-table th,
        .historical-table td {
            padding: 12px 16px;
            text-align: left;
            border-bottom: 1px solid #E5E5E5;
        }

        .historical-table th {
            font-size: 12px;
            color: #86868B;
            font-weight: 500;
        }

        .historical-table td {
            font-size: 14px;
        }

        /* Loading & Error States */
        .loading {
            text-align: center;
            padding: 40px;
            color: #86868B;
        }

        .error-message {
            background: #FF3B3020;
            color: #FF3B30;
            padding: 16px;
            border-radius: 8px;
            margin-bottom: 16px;
        }

        .hidden {
            display: none;
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>股票分红计算器</h1>
        </header>

        <div class="main-content">
            <!-- Input Card -->
            <div class="card">
                <h2 class="card-title">持仓信息</h2>
                <div class="form-group">
                    <label>股票代码</label>
                    <input type="text" id="stockCode" placeholder="输入股票代码 如601318" value="601318">
                </div>
                <div class="form-group">
                    <label>成本价 (元)</label>
                    <input type="number" id="costPrice" placeholder="如 21.423" step="0.001" value="21.423">
                </div>
                <div class="form-group">
                    <label>持股数量 (股)</label>
                    <input type="number" id="shares" placeholder="如 1000" value="1000">
                </div>
                <button class="btn-calculate" id="calculateBtn" onclick="calculateDividend()">计算分红</button>
            </div>

            <!-- Result Card -->
            <div class="card">
                <h2 class="card-title">分红结果</h2>
                <div id="resultContent">
                    <div class="loading">请输入持仓信息并点击计算</div>
                </div>
            </div>
        </div>

        <!-- Historical Comparison -->
        <div class="historical-section">
            <h2 class="historical-title">历史年度对比</h2>
            <table class="historical-table">
                <thead>
                    <tr>
                        <th>年度</th>
                        <th>每股分红 (元)</th>
                        <th>成本价股息率</th>
                        <th>当前价股息率</th>
                    </tr>
                </thead>
                <tbody id="historicalTable">
                    <tr>
                        <td colspan="4" style="text-align: center; color: #86868B;">暂无数据</td>
                    </tr>
                </tbody>
            </table>
        </div>
    </div>

    <script>
        async function calculateDividend() {
            const code = document.getElementById('stockCode').value.trim();
            const costPrice = parseFloat(document.getElementById('costPrice').value);
            const shares = parseInt(document.getElementById('shares').value);
            const btn = document.getElementById('calculateBtn');

            if (!code || !costPrice || !shares) {
                alert('请填写完整信息');
                return;
            }

            btn.disabled = true;
            btn.textContent = '计算中...';

            try {
                const response = await fetch(`/api/dividend?code=${code}&cost_price=${costPrice}&shares=${shares}`);
                const result = await response.json();

                if (result.success) {
                    renderResult(result.data);
                    renderHistorical(result.data.historical_comparison);
                } else {
                    document.getElementById('resultContent').innerHTML = `
                        <div class="error-message">${result.error || '计算失败'}</div>
                    `;
                }
            } catch (error) {
                document.getElementById('resultContent').innerHTML = `
                    <div class="error-message">网络错误，请重试</div>
                `;
            } finally {
                btn.disabled = false;
                btn.textContent = '计算分红';
            }
        }

        function renderResult(data) {
            const html = `
                <div class="result-header">
                    <span class="stock-name">${data.stock_name}</span>
                    <span class="prev-close">昨收 ${data.prev_close.toFixed(3)} 元</span>
                </div>
                <div class="metrics-grid">
                    <div class="metric">
                        <div class="metric-label">成本价股息率</div>
                        <div class="metric-value">${data.cost_yield_rate.toFixed(2)}<span class="metric-unit">%</span></div>
                    </div>
                    <div class="metric">
                        <div class="metric-label">当前价股息率</div>
                        <div class="metric-value">${data.current_yield_rate.toFixed(2)}<span class="metric-unit">%</span></div>
                    </div>
                    <div class="metric">
                        <div class="metric-label">每股分红</div>
                        <div class="metric-value">${data.per_share_dividend.toFixed(4)}<span class="metric-unit">元</span></div>
                    </div>
                    <div class="metric">
                        <div class="metric-label">年度总分红</div>
                        <div class="metric-value highlight">${data.yearly_total_dividend.toFixed(2)}<span class="metric-unit">元</span></div>
                    </div>
                    <div class="metric" style="grid-column: span 2;">
                        <div class="metric-label">预计回收成本</div>
                        <div class="metric-value highlight">${data.cost_recovery_years.toFixed(1)}<span class="metric-unit">年</span></div>
                    </div>
                </div>
                ${data.yearly_details.length > 0 ? `
                <div class="dividend-details">
                    <div class="detail-title">年度分红明细</div>
                    ${data.yearly_details.map(d => `
                        <div class="detail-item">
                            <span>${d.type} ${d.desc}</span>
                            <span class="detail-status ${d.is_paid ? 'status-paid' : 'status-pending'}">
                                ${d.is_paid ? '✓ 已派息' : '◐ 待派息'}
                            </span>
                        </div>
                    `).join('')}
                </div>
                ` : '<div class="loading">暂无本年度分红数据</div>'}
            `;
            document.getElementById('resultContent').innerHTML = html;
        }

        function renderHistorical(historical) {
            if (!historical || historical.length === 0) {
                document.getElementById('historicalTable').innerHTML = `
                    <tr>
                        <td colspan="4" style="text-align: center; color: #86868B;">暂无历史数据</td>
                    </tr>
                `;
                return;
            }

            const html = historical.map(h => `
                <tr>
                    <td>${h.year}</td>
                    <td>${h.per_share.toFixed(4)}</td>
                    <td>${h.cost_yield.toFixed(2)}%</td>
                    <td>${h.current_yield.toFixed(2)}%</td>
                </tr>
            `).join('');
            document.getElementById('historicalTable').innerHTML = html;
        }
    </script>
</body>
</html>
```

- [ ] **Step 3: 提交代码**

```bash
git add templates/index.html
git commit -m "feat: add frontend HTML/CSS/JS page"
```

---

### Task 3: 安装依赖并测试

**Files:**
- Modify: `stock-dividend-calculator/requirements.txt`

- [ ] **Step 1: 安装 Python 依赖**

```bash
pip install Flask>=2.3.0
```

- [ ] **Step 2: 启动 Flask 应用并测试**

```bash
cd stock-dividend-calculator
python app.py
```

测试 API:
```bash
curl "http://localhost:5000/api/dividend?code=601318&cost_price=21.423&shares=1000"
```

预期返回 JSON 数据，包含 stock_name, prev_close, cost_yield_rate, current_yield_rate 等字段。

- [ ] **Step 3: 浏览器访问测试**

打开浏览器访问 http://localhost:5000，输入股票代码 601318，成本价 21.423，股数 1000，点击计算分红。

验证:
1. 分红结果卡片显示成本价股息率和当前价股息率
2. 显示预计回收成本时间
3. 历史表格显示 2024/2023/2022 三年数据

- [ ] **Step 4: 提交测试结果**

```bash
git add -A
git commit -m "test: verify Flask app and API work correctly"
```

---

## 验收标准检查清单

- [ ] 输入 601318/21.423/1000 能正确返回分红数据
- [ ] 成本价股息率和当前价股息率同时显示
- [ ] 预计回收成本时间计算正确
- [ ] 历史表格显示 2024/2023/2022 三年数据
- [ ] 界面符合简约 Apple 风格
- [ ] 移动端响应式布局正常
- [ ] 网络错误时有友好提示
