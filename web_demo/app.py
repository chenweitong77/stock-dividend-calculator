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
