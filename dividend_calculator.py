# -*- coding: utf-8 -*-
"""
股票分红计算模块

核心逻辑：
  - 按利润归属年度（PAYYEAR）归类分红，而非按派息日期
  - 股息率 = 全年每股分红合计 / 成本价 × 100%
"""

from typing import List, Dict, Any, Optional
from stock_api import EastMoneyDividendAPI


class DividendCalculator:
    """分红收益计算器"""

    def __init__(self, cost_price: float, shares: int):
        """
        Args:
            cost_price: 用户持仓成本价（元）
            shares: 持仓数量（股）
        """
        self.cost_price = cost_price
        self.shares = shares
        self.total_cost = cost_price * shares

    def get_yearly_dividend(
        self, dividend_records: List[Dict[str, Any]], year: str
    ) -> Dict[str, Any]:
        """
        获取指定年度的分红数据（按 PAYYEAR 归类）

        Args:
            dividend_records: 分红记录列表
            year: 年份字符串，如 "2025"

        Returns:
            包含以下字段的字典：
            - year: 年份
            - total_per_share: 全年每股分红合计（元）
            - detail: 各次分红明细列表
            - has_mid_year: 是否有中报分红
            - has_full_year: 是否有年报分红
            - is_announced: 年报是否已公告
            - is_paid: 分红是否已派息到账
        """
        yearly_records = []
        total_per_share = 0.0

        for r in dividend_records:
            pay_year = str(r.get("PAYYEAR") or "")

            if pay_year != year:
                continue

            assign_desc = r.get("ASSIGNDSCRPT") or ""
            if not assign_desc:
                continue

            div_per_share = EastMoneyDividendAPI.parse_dividend_per_share(assign_desc)
            if div_per_share <= 0:
                continue

            yearly_records.append(
                {
                    "type": self._detect_dividend_type(r, year),
                    "desc": assign_desc,
                    "per_share": div_per_share,
                    "notice_date": r.get("NOTICE_DATE", "")[:10]
                    if r.get("NOTICE_DATE")
                    else "",
                    "ex_date": r.get("EITIME", "")[:10]
                    if r.get("EITIME")
                    else "",
                    "is_paid": self._check_if_paid(r),
                }
            )
            total_per_share += div_per_share

        return {
            "year": year,
            "total_per_share": round(total_per_share, 4),
            "detail": yearly_records,
            "has_mid_year": any(rec["type"] == "中报" for rec in yearly_records),
            "has_full_year": any(rec["type"] == "年报" for rec in yearly_records),
            "has_q1": any(rec["type"] == "一季报" for rec in yearly_records),
            "has_q3": any(rec["type"] == "三季报" for rec in yearly_records),
            "is_announced": len(yearly_records) > 0,
            "is_paid": all(rec["is_paid"] for rec in yearly_records),
        }

    def _detect_dividend_type(self, record: Dict[str, Any], year: str) -> str:
        """
        根据公告日期年份判断分红类型：
        - 年报: 公告年份 = 归属年份 + 1（所有月份都是年报）
        - 一季报: 公告年份 = 归属年份，除权在3-6月
        - 中报: 公告年份 = 归属年份，除权在7-9月
        - 三季报: 公告年份 = 归属年份，除权在10-12月
        """
        notice_date = record.get("NOTICE_DATE", "")
        eitime = record.get("EITIME", "")

        if not notice_date:
            return "其他"

        # 规则：公告年份 = 归属年份 + 1 → 年报
        notice_year = notice_date[:4]
        if notice_year == str(int(year) + 1):
            return "年报"

        # 公告年份 = 归属年份，看除权月份
        if notice_year == year:
            month = int(eitime[5:7]) if len(eitime) >= 7 else 0
            if 3 <= month <= 6:
                return "一季报"
            elif 7 <= month <= 9:
                return "中报"
            elif 10 <= month <= 12:
                return "三季报"

        return "其他"

    def _is_mid_year_record(self, records: List[Dict]) -> bool:
        """判断是否有中报分红（根据除权日期在7-9月）"""
        for rec in records:
            ex_date = rec.get("ex_date", "")
            if ex_date:
                month = int(ex_date[5:7]) if len(ex_date) >= 7 else 0
                if 7 <= month <= 9:
                    return True
        return False

    def _is_full_year_record(self, records: List[Dict]) -> bool:
        """判断是否有年报分红（根据除权日期在次年3-5月）"""
        for rec in records:
            ex_date = rec.get("ex_date", "")
            if ex_date:
                month = int(ex_date[5:7]) if len(ex_date) >= 7 else 0
                if 3 <= month <= 5:
                    return True
        return False

    def _check_if_paid(self, record: Dict[str, Any]) -> bool:
        """检查分红是否已派息到账"""
        eitime = record.get("EITIME", "")
        if not eitime:
            return False
        try:
            from datetime import datetime

            eitime_date = datetime.strptime(eitime[:10], "%Y-%m-%d")
            return eitime_date <= datetime.now()
        except Exception:
            return False

    def calc_yield_rate(self, yearly_dividend_per_share: float) -> float:
        """
        计算股息率

        Args:
            yearly_dividend_per_share: 全年每股分红合计（元）

        Returns:
            股息率（%）
        """
        if self.cost_price <= 0:
            return 0.0
        return round(yearly_dividend_per_share / self.cost_price * 100, 4)

    def calc_total_dividend(self, yearly_dividend_per_share: float) -> float:
        """
        计算用户持股总分红金额

        Args:
            yearly_dividend_per_share: 全年每股分红合计（元）

        Returns:
            总分红金额（元）
        """
        return round(yearly_dividend_per_share * self.shares, 2)


class StockPosition:
    """用户持仓信息"""

    def __init__(
        self,
        code: str,
        name: str,
        cost_price: float,
        shares: int,
        current_price: float = 0.0,
        prev_close: float = 0.0,
    ):
        self.code = code
        self.name = name
        self.cost_price = cost_price
        self.shares = shares
        self.current_price = current_price
        self.prev_close = prev_close

    @property
    def total_cost(self) -> float:
        return self.cost_price * self.shares

    @property
    def market_value(self) -> float:
        return self.current_price * self.shares

    @property
    def floating_pnl(self) -> float:
        return (self.current_price - self.cost_price) * self.shares

    @property
    def floating_rate(self) -> float:
        if self.cost_price <= 0:
            return 0.0
        return (self.current_price - self.cost_price) / self.cost_price * 100

    def calc_dividend(
        self, dividend_records: List[Dict[str, Any]], year: str
    ) -> Dict[str, Any]:
        """
        计算指定年度的分红收益

        Args:
            dividend_records: 分红记录列表
            year: 年份（如 "2025"）

        Returns:
            包含完整分红计算结果的字典
        """
        calc = DividendCalculator(self.cost_price, self.shares)
        yearly_info = calc.get_yearly_dividend(dividend_records, year)
        yield_rate = calc.calc_yield_rate(yearly_info["total_per_share"])
        total_dividend = calc.calc_total_dividend(yearly_info["total_per_share"])

        return {
            "stock": {
                "code": self.code,
                "name": self.name,
                "cost_price": self.cost_price,
                "shares": self.shares,
                "total_cost": self.total_cost,
                "current_price": self.current_price,
                "prev_close": self.prev_close,
                "market_value": self.market_value,
                "floating_pnl": self.floating_pnl,
                "floating_rate": self.floating_rate,
            },
            "dividend_year": year,
            "yearly_info": yearly_info,
            "yield_rate": yield_rate,
            "total_dividend": total_dividend,
        }


def format_dividend_report(result: Dict[str, Any]) -> str:
    """
    格式化分红报告为易读字符串

    Args:
        result: StockPosition.calc_dividend() 返回的结果

    Returns:
        格式化的报告字符串
    """
    stock = result["stock"]
    yearly = result["yearly_info"]

    lines = [
        "=" * 60,
        f"  {stock['name']} ({stock['code']}) - {result['dividend_year']}年度分红报告",
        "=" * 60,
        "",
        "【持仓信息】",
        f"  成本价: {stock['cost_price']:.3f} 元",
        f"  持仓: {stock['shares']} 股",
        f"  成本: {stock['total_cost']:,.2f} 元",
        f"  当前市值: {stock['market_value']:,.2f} 元 (昨收{stock['prev_close']:.3f})",
        f"  浮盈/亏: {stock['floating_pnl']:+,.2f} 元 ({stock['floating_rate']:+.2f}%)",
        "",
        "【分红明细】",
    ]

    for rec in yearly["detail"]:
        status = "✅已派息" if rec["is_paid"] else "⚠️待派息"
        lines.append(
            f"  • {rec['type']} {rec['desc']} → "
            f"每股 {rec['per_share']:.4f} 元 [{status}]"
        )

    lines.extend(
        [
            "",
            f"  全年每股合计: {yearly['total_per_share']:.4f} 元",
            "-" * 60,
            f"  💰 持股分红: {result['total_dividend']:,.2f} 元",
            f"  📊 股息率: {result['yield_rate']:.2f}%",
            "=" * 60,
        ]
    )

    return "\n".join(lines)
