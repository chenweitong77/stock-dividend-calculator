# -*- coding: utf-8 -*-
"""
股票分红计算器 Web Demo - Flask 应用入口
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from flask import Flask, render_template, request, jsonify
from dividend_calculator import StockPosition, format_dividend_report
from stock_api import get_stock_info
from stock_name_map import search_stocks, _load_full_stock_list

app = Flask(__name__)

# 应用启动时预加载股票列表
print("[INFO] 正在初始化股票数据...")
_load_full_stock_list()


@app.route('/')
def index():
    """渲染前端页面"""
    return render_template('index.html')


@app.route('/api/search')
def api_search():
    """
    股票搜索 API

    请求参数:
        keyword: 股票代码或名称
    """
    keyword = request.args.get('keyword', '').strip()

    if not keyword:
        return jsonify({
            'success': False,
            'data': None,
            'error': '请输入股票代码或名称'
        })

    try:
        results = search_stocks(keyword)

        if results:
            return jsonify({
                'success': True,
                'data': results,
                'error': None
            })
        else:
            return jsonify({
                'success': False,
                'data': None,
                'error': f'未找到股票 "{keyword}"'
            })
    except Exception as e:
        return jsonify({
            'success': False,
            'data': None,
            'error': str(e)
        })


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
            # 股票无分红记录，但行情数据获取成功，仍返回成功（兼容无分红的情况）
            position = StockPosition(
                code=code,
                name=price_info.get('name', ''),
                cost_price=cost_price,
                shares=shares,
                current_price=price_info.get('current', 0),
                prev_close=price_info.get('prev_close', 0),
            )
            return jsonify({
                'success': True,
                'data': {
                    'stock_name': price_info.get('name', ''),
                    'prev_close': price_info.get('prev_close', 0),
                    'current_price': price_info.get('current', 0),
                    'cost_yield_rate': 0.0,
                    'current_yield_rate': 0.0,
                    'per_share_dividend': 0.0,
                    'yearly_total_dividend': 0.0,
                    'cost_recovery_years': 0,
                    'yearly_details': [],
                    'historical_comparison': [],
                    'is_announced': False,
                    'is_paid': False,
                    'no_dividend': True,
                    'message': '该股票暂无分红记录'
                },
                'error': None
            })

        position = StockPosition(
            code=code,
            name=price_info.get('name', ''),
            cost_price=cost_price,
            shares=shares,
            current_price=price_info.get('current', 0),
            prev_close=price_info.get('prev_close', 0),
        )

        # 获取所有年份的分红数据
        all_years_data = {}
        for y in ['2025', '2024', '2023', '2022']:
            yearly = position.calc_dividend(dividend_records, year=y)
            if yearly['yearly_info']['detail']:
                all_years_data[y] = {
                    'per_share': yearly['yearly_info']['total_per_share'],
                    'total_dividend': yearly['total_dividend'],
                    'yield_rate': yearly['yield_rate'],
                    'detail': yearly['yearly_info']['detail'],
                    'is_announced': yearly['yearly_info']['is_announced'],
                    'is_paid': yearly['yearly_info']['is_paid'],
                }

        # 使用传入的 year 或者最新可用年份
        if year not in all_years_data:
            year = '2025' if '2025' in all_years_data else sorted(all_years_data.keys())[0] if all_years_data else '2025'

        result = position.calc_dividend(dividend_records, year=year)

        # 构建历史对比数据（用于表格展示）
        historical = []
        for y in ['2024', '2023', '2022']:
            if y in all_years_data:
                historical.append({
                    'year': y,
                    'per_share': all_years_data[y]['per_share'],
                    'cost_yield': all_years_data[y]['yield_rate'],
                    'current_yield': all_years_data[y]['yield_rate'] * cost_price / price_info.get('prev_close', 1) if price_info.get('prev_close') else 0
                })

        return jsonify({
            'success': True,
            'data': {
                'stock_name': result['stock']['name'],
                'prev_close': result['stock']['prev_close'],
                'current_price': price_info.get('current', 0),
                'cost_yield_rate': result['yield_rate'],
                'current_yield_rate': result['yield_rate'] * cost_price / price_info.get('prev_close', 1) if price_info.get('prev_close') else 0,
                'per_share_dividend': result['yearly_info']['total_per_share'],
                'yearly_total_dividend': result['total_dividend'],
                'cost_recovery_years': round(result['stock']['total_cost'] / result['total_dividend'], 2) if result['total_dividend'] > 0 else 0,
                'yearly_details': result['yearly_info']['detail'],
                'historical_comparison': historical,
                'is_announced': result['yearly_info']['is_announced'],
                'is_paid': result['yearly_info']['is_paid'],
                'no_dividend': False,
                # 新增：所有年份的汇总数据
                'all_years_summary': {
                    y: {
                        'per_share': data['per_share'],
                        'total_dividend': data['total_dividend'],
                        'yield_rate': data['yield_rate'],
                        'has_detail': len(data['detail']) > 0
                    }
                    for y, data in all_years_data.items()
                }
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
    app.run(debug=False, host='0.0.0.0', port=5000)
