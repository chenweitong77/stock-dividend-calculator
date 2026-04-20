# -*- coding: utf-8 -*-
"""
股票分红计算器 - 主程序

演示如何调用 stock_api 和 dividend_calculator
"""

from stock_api import get_stock_info, SinaStockAPI
from dividend_calculator import StockPosition, format_dividend_report


def main():
    """演示：中国平安持仓分析"""

    # ======== 用户持仓数据 ========
    # 可自行修改为其他股票
    user_position = {
        "code": "601318",
        "name": "中国平安",
        "cost_price": 21.423,
        "shares": 1000,
    }

    # ======== 获取数据 ========
    code = user_position["code"]
    print(f"正在获取 {code} 数据...\n")

    stock_info = get_stock_info(code)
    price_info = stock_info["price_info"]
    dividend_records = stock_info["dividend_records"]

    if not price_info:
        print("❌ 获取行情数据失败")
        return

    if not dividend_records:
        print("❌ 获取分红数据失败")
        return

    print(f"✅ 行情数据: {price_info['name']} 昨收 {price_info['prev_close']:.3f}元")
    print(f"✅ 分红记录: {len(dividend_records)} 条\n")

    # ======== 计算分红 ========
    position = StockPosition(
        code=user_position["code"],
        name=user_position["name"],
        cost_price=user_position["cost_price"],
        shares=user_position["shares"],
        current_price=price_info.get("current", 0),
        prev_close=price_info.get("prev_close", 0),
    )

    # 计算 2025 年度分红
    result = position.calc_dividend(dividend_records, year="2025")

    # 打印报告
    print(format_dividend_report(result))

    # ======== 打印历史股息率对比 ========
    print("\n【历史股息率参考】")
    print("-" * 45)
    print(f"{'年度':<8} {'每股分红':>12} {'成本价股息率':>14}")
    print("-" * 45)

    calc = StockPosition(
        code=code,
        name=user_position["name"],
        cost_price=user_position["cost_price"],
        shares=user_position["shares"],
    )

    for year in ["2024", "2023", "2022"]:
        yearly = calc.calc_dividend(dividend_records, year)
        if yearly["yearly_info"]["detail"]:
            per_share = yearly["yearly_info"]["total_per_share"]
            yield_rate = yearly["yield_rate"]
            print(f"{year:<8} {per_share:>10.4f} 元 {yield_rate:>12.2f}%")


if __name__ == "__main__":
    main()
