#!/usr/bin/env python3
"""
BSC节点高度监控脚本（带官方节点对比）
功能：每10秒检查本地节点高度，与官方节点对比，连续5次本地节点高度无变化或落后官方节点超过3个区块时报警
"""

import time
import json
import logging
import sys
import os
from datetime import datetime
from typing import Optional, Tuple

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

# ================== 配置区域 ==================
# Telegram配置（从环境变量读取）
TELEGRAM_BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN", "")
TELEGRAM_CHAT_ID = os.getenv("TELEGRAM_CHAT_ID", "")

# 节点配置
LOCAL_NODE_URL = os.getenv("LOCAL_NODE_URL", "http://127.0.0.1:10575")
OFFICIAL_NODE_URL = os.getenv("OFFICIAL_NODE_URL", "https://bsc-testnet-dataseed.bnbchain.org")
RPC_METHOD = "eth_blockNumber"

# 监控配置
CHECK_INTERVAL = int(os.getenv("CHECK_INTERVAL", "10"))              # 检查间隔（秒）
MAX_NO_CHANGE_COUNT = int(os.getenv("MAX_NO_CHANGE_COUNT", "5"))    # 本地节点最大允许的无变化次数
MAX_HEIGHT_DIFF = int(os.getenv("MAX_HEIGHT_DIFF", "3"))            # 最大允许的高度差

# 日志配置
LOG_LEVEL = logging.INFO
LOG_FORMAT = '%(asctime)s - %(levelname)s - %(message)s'
# =============================================

# 配置日志
logging.basicConfig(
    level=LOG_LEVEL,
    format=LOG_FORMAT,
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler('bsc_monitor.log', encoding='utf-8')
    ]
)
logger = logging.getLogger(__name__)


def create_session_with_retry() -> requests.Session:
    """创建带重试机制的requests会话"""
    session = requests.Session()
    retry_strategy = Retry(
        total=3,
        backoff_factor=1,
        status_forcelist=[429, 500, 502, 503, 504],
    )
    adapter = HTTPAdapter(max_retries=retry_strategy, pool_connections=10, pool_maxsize=20)
    session.mount("http://", adapter)
    session.mount("https://", adapter)
    return session


def get_block_height(session: requests.Session, node_url: str, node_name: str = "节点") -> Optional[int]:
    """
    获取指定节点的区块高度
    :param session: requests会话对象
    :param node_url: 节点RPC地址
    :param node_name: 节点名称（用于日志）
    :return: 区块高度（十进制整数），失败返回None
    """
    payload = {
        "jsonrpc": "2.0",
        "method": RPC_METHOD,
        "params": [],
        "id": 1
    }
    
    try:
        response = session.post(node_url, json=payload, timeout=10)
        response.raise_for_status()
        data = response.json()
        
        if "error" in data:
            logger.error(f"{node_name} RPC错误: {data['error']}")
            return None
        
        # 将十六进制高度转换为十进制整数
        hex_height = data.get("result")
        if hex_height:
            return int(hex_height, 16)
        else:
            logger.error(f"{node_name} 响应中未找到result字段")
            return None
            
    except requests.exceptions.RequestException as e:
        logger.error(f"请求{node_name}失败: {e}")
        return None
    except (json.JSONDecodeError, ValueError, KeyError) as e:
        logger.error(f"解析{node_name}响应失败: {e}")
        return None


def send_telegram_alert(session: requests.Session, message: str) -> bool:
    """
    发送Telegram报警消息
    :param session: requests会话对象
    :param message: 消息内容
    :return: 发送成功返回True
    """
    if not TELEGRAM_BOT_TOKEN or not TELEGRAM_CHAT_ID:
        logger.warning("Telegram配置未设置，跳过发送告警")
        return False
    
    url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage"
    payload = {
        "chat_id": TELEGRAM_CHAT_ID,
        "text": message,
        "parse_mode": "HTML"
    }
    
    try:
        response = session.post(url, json=payload, timeout=10)
        response.raise_for_status()
        logger.info("Telegram报警发送成功")
        return True
    except Exception as e:
        logger.error(f"发送Telegram报警失败: {e}")
        return False


def format_alert_message(
    alert_type: str,
    local_height: int,
    official_height: int,
    height_diff: int,
    no_change_count: int,
    start_time: str
) -> str:
    """
    格式化报警消息
    """
    if alert_type == "no_change":
        title = "⚠️ BSC节点高度无变化告警 ⚠️"
        detail = f"连续 {no_change_count} 次检查高度无变化"
    else:
        title = "⚠️ BSC节点高度落后告警 ⚠️"
        detail = f"本地节点落后官方节点 {height_diff} 个区块（阈值: {MAX_HEIGHT_DIFF}）"
    
    return (
        f"{title}\n\n"
        f"<b>节点地址</b>: {LOCAL_NODE_URL}\n"
        f"<b>本地高度</b>: <code>{local_height}</code>\n"
        f"<b>官方高度</b>: <code>{official_height}</code>\n"
        f"<b>高度差</b>: {height_diff}\n"
        f"<b>{detail}</b>\n"
        f"<b>监控开始时间</b>: {start_time}\n"
        f"<b>告警时间</b>: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n"
        f"请检查本地节点是否正常运行或同步！"
    )


def check_node_health(
    session: requests.Session,
    local_height: Optional[int],
    official_height: Optional[int],
    last_local_height: Optional[int],
    no_change_count: int,
    alert_sent_no_change: bool,
    alert_sent_behind: bool,
    start_time: str
) -> Tuple[int, bool, bool]:
    """
    检查节点健康状态并触发告警
    返回: (new_no_change_count, new_alert_sent_no_change, new_alert_sent_behind)
    """
    current_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    
    # 检查本地节点高度是否获取成功
    if local_height is None:
        logger.warning(f"[{current_time}] 获取本地节点高度失败")
        if not alert_sent_no_change and not alert_sent_behind:
            send_telegram_alert(
                session,
                f"❌ BSC本地节点异常\n"
                f"节点地址: {LOCAL_NODE_URL}\n"
                f"时间: {current_time}\n"
                f"无法获取区块高度，请检查节点服务！"
            )
        return no_change_count, alert_sent_no_change, alert_sent_behind
    
    # 检查官方节点
    if official_height is None:
        logger.warning(f"[{current_time}] 获取官方节点高度失败，跳过对比")
        # 官方节点失败时只记录日志，继续监控本地节点
        return no_change_count, alert_sent_no_change, alert_sent_behind
    
    logger.info(f"[{current_time}] 本地高度: {local_height}, 官方高度: {official_height}, 差值: {official_height - local_height}")
    
    # 检查高度差
    height_diff = official_height - local_height
    is_behind = height_diff > MAX_HEIGHT_DIFF
    
    # 首次获取，初始化状态
    if last_local_height is None:
        return 0, False, False
    
    # 处理高度无变化告警
    if local_height == last_local_height:
        no_change_count += 1
        logger.warning(f"本地高度无变化 (连续 {no_change_count}/{MAX_NO_CHANGE_COUNT} 次)")
        
        if no_change_count >= MAX_NO_CHANGE_COUNT and not alert_sent_no_change:
            alert_msg = format_alert_message(
                "no_change",
                local_height,
                official_height,
                height_diff,
                no_change_count,
                start_time
            )
            send_telegram_alert(session, alert_msg)
            alert_sent_no_change = True
    else:
        # 高度发生变化，重置无变化计数和告警状态
        if no_change_count > 0:
            logger.info(f"本地高度变化: {last_local_height} -> {local_height}")
        no_change_count = 0
        alert_sent_no_change = False
    
    # 处理高度落后告警
    if is_behind and not alert_sent_behind:
        alert_msg = format_alert_message(
            "behind",
            local_height,
            official_height,
            height_diff,
            no_change_count,
            start_time
        )
        send_telegram_alert(session, alert_msg)
        alert_sent_behind = True
    elif not is_behind:
        # 恢复正常，重置落后告警状态
        if alert_sent_behind:
            logger.info(f"本地节点已追上，高度差: {height_diff}")
            send_telegram_alert(
                session,
                f"✅ BSC本地节点已恢复正常\n"
                f"节点地址: {LOCAL_NODE_URL}\n"
                f"本地高度: {local_height}\n"
                f"官方高度: {official_height}\n"
                f"高度差: {height_diff}\n"
                f"恢复时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
            )
        alert_sent_behind = False
    
    return no_change_count, alert_sent_no_change, alert_sent_behind


def main():
    """主监控循环"""
    logger.info("=" * 60)
    logger.info("BSC节点监控脚本启动（带官方节点对比）")
    logger.info(f"本地节点: {LOCAL_NODE_URL}")
    logger.info(f"官方节点: {OFFICIAL_NODE_URL}")
    logger.info(f"检查间隔: {CHECK_INTERVAL}秒")
    logger.info(f"高度落后告警阈值: {MAX_HEIGHT_DIFF}个区块")
    logger.info(f"无变化告警阈值: 连续{MAX_NO_CHANGE_COUNT}次无变化")
    logger.info("=" * 60)
    
    # 检查Telegram配置
    if not TELEGRAM_BOT_TOKEN or not TELEGRAM_CHAT_ID:
        logger.warning("⚠️  Telegram配置未设置，告警功能将被禁用")
        logger.warning("请设置环境变量: TELEGRAM_BOT_TOKEN 和 TELEGRAM_CHAT_ID")
    
    # 创建带重试机制的会话
    session = create_session_with_retry()
    
    # 初始化监控状态
    last_local_height: Optional[int] = None
    no_change_count = 0
    alert_sent_no_change = False
    alert_sent_behind = False
    start_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    
    # 启动时测试连接
    logger.info("测试节点连接...")
    test_local = get_block_height(session, LOCAL_NODE_URL, "本地节点")
    test_official = get_block_height(session, OFFICIAL_NODE_URL, "官方节点")
    
    if test_local is None:
        logger.error("无法连接到本地节点，请检查节点配置")
        send_telegram_alert(
            session,
            f"❌ BSC监控启动失败\n无法连接到本地节点: {LOCAL_NODE_URL}"
        )
        sys.exit(1)
    
    if test_official is None:
        logger.warning("无法连接到官方节点，将只监控本地节点高度变化")
        send_telegram_alert(
            session,
            f"⚠️ BSC监控启动警告\n无法连接到官方节点: {OFFICIAL_NODE_URL}\n将只监控本地节点高度变化"
        )
    else:
        logger.info(f"初始状态 - 本地高度: {test_local}, 官方高度: {test_official}")
    
    try:
        while True:
            # 获取本地节点高度
            current_local_height = get_block_height(session, LOCAL_NODE_URL, "本地节点")
            
            # 获取官方节点高度
            current_official_height = get_block_height(session, OFFICIAL_NODE_URL, "官方节点")
            
            # 检查节点健康状态
            no_change_count, alert_sent_no_change, alert_sent_behind = check_node_health(
                session,
                current_local_height,
                current_official_height,
                last_local_height,
                no_change_count,
                alert_sent_no_change,
                alert_sent_behind,
                start_time
            )
            
            # 更新最后高度
            if current_local_height is not None:
                last_local_height = current_local_height
            
            # 等待下一次检查
            time.sleep(CHECK_INTERVAL)
            
    except KeyboardInterrupt:
        logger.info("收到中断信号，监控脚本退出")
        send_telegram_alert(session, "🛑 BSC监控脚本已停止")
        sys.exit(0)
    except Exception as e:
        logger.exception(f"监控循环发生未预期异常: {e}")
        send_telegram_alert(session, f"🔥 BSC监控脚本异常退出\n错误: {str(e)}")
        sys.exit(1)
    finally:
        session.close()


if __name__ == "__main__":
    main()
