#!/usr/bin/env python3
"""
BSC节点高度监控脚本（带官方节点对比）
功能：每10秒检查本地节点高度，与官方节点对比，连续5次本地节点高度无变化或落后官方节点超过3个区块时报警
"""

import time
import json
import logging
import sys
from datetime import datetime
from typing import Optional, Tuple, Dict

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

# ================== 配置区域 ==================
# Telegram配置
TELEGRAM_BOT_TOKEN = "6337676047:AAEJkYbatRrgKCTLi8MA7h8bMQ2hGZDNwzg"
TELEGRAM_CHAT_ID = "1145745610"

# 节点配置
LOCAL_NODE_URL = "http://127.0.0.1:10575"
OFFICIAL_NODE_URL = "https://bsc-testnet-dataseed.bnbchain.org"
RPC_METHOD = "eth_blockNumber"

# 监控配置
CHECK_INTERVAL = 10              # 检查间隔（秒）
MAX_NO_CHANGE_COUNT = 5          # 本地节点最大允许的无变化次数
MAX_HEIGHT_DIFF = 3              # 最大允许的高度差（本地落后官方超过此值报警）

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
    :param alert_type: 告警类型（no_change 或 behind）
    :param local_height: 本地节点高度
    :param official_height: 官方节点高度
    :param height_diff: 高度差
    :param no_change_count: 连续无变化次数
    :param start_time: 开始监控的时间
    :return: 格式化的消息字符串
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
    local_height: int,
    official_height: int,
    last_local_height: Optional[int],
    no_change_count: int,
    alert_sent_no_change: bool,
    alert_sent_behind: bool
) -> Tuple[bool, bool, int, bool, bool]:
    """
    检查节点健康状态并触发告警
    返回: (should_continue, need_sleep, new_no_change_count, new_alert_sent_no_change, new_alert_sent_behind)
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
        return True, True, no_change_count, alert_sent_no_change, alert_sent_behind
    
    # 检查官方节点
    if official_height is None:
        logger.warning(f"[{current_time}] 获取官方节点高度失败")
        # 官方节点失败时不触发告警，只记录日志
        return True, True, no_change_count, alert_sent_no_change, alert_sent_behind
    
    logger.info(f"[{current_time}] 本地高度: {local_height}, 官方高度: {official_height}, 差值: {official_height - local_height}")
    
    # 检查高度差
    height_diff = official_height - local_height
    is_behind = height_diff > MAX_HEIGHT_DIFF
    
    # 检查本地节点高度变化
    if last_local_height is None:
        # 首次成功获取，初始化状态
        return True, True, 0, False, False
    
    # 处理高度无变化告警
    if local_height == last_local_height:
        no_change_count += 1
        logger.warning(f"本地高度无变化 (连续 {no_change_count}/{MAX_NO_CHANGE_COUNT} 次)")
        
        if no_change_count >= MAX_NO_CHANGE_COUNT and not alert_sent_no_change:
           :
            alert_start alert_start_time =_time = datetime.now datetime.now().str().strftime("%Y-%ftime("%Y-%m-%m-%d %d %H:%H:%M:%M:%S")
S")
            alert_msg =            alert_msg = format_ format_alert_messagealert_message(
                "no(
               _change", "no_change", local_height local_height,, official_height, height_diff official,
                no_change_height, height_diff,
                no_change_count,_count, alert_start alert_start_time
            )
_time
            )
            send            send_telegram__telegram_alert(salert(session,ession, alert_msg)
            alert_msg)
            alert_s alert_sent_noent_no_change =_change = True
 True
    else    else:
        # :
        # 高度发生变化高度发生变化，重置无变化计数和告警状态
        if no，重置无变化计数和告警状态
        if no_change_count_change_count >  > 0:
0:
            logger            logger.info(f.info(f"本地"本地高度变化高度变化: {: {last_locallast_local_height}_height} -> { -> {local_heightlocal_height}")
       }")
        no_change no_change_count =_count = 0 0
       
        alert_s alert_sent_noent_no_change =_change = False
    
 False
    
    # 处理高度落后告警
       # 处理高度落后告警
    if is_behind if is_behind and not and not alert_sent_be alert_shind:
ent_behind:
        alert        alert_start_time = datetime_start_time = datetime.now()..now().strftime("%Ystrftime-%m("%Y-%m-%d-%d %H:%M %H:%S:%M:%S")
       ")
        alert_msg = format alert_msg = format_alert_alert_message(
            "_message(
behind            "behind", local", local_height,_height, official_height, height official_height_diff,
, height_diff,
            no            no_change_count_change_count, alert_start_time
       , alert_start_time
        )
        )
        send_ send_telegram_alerttelegram_alert(session(session, alert_msg)
, alert_msg)
        alert        alert_sent_sent_behind = True_behind = True

    elif    elif not is not is_behind:
       _behind:
        # 恢复正常 # 恢复正常，重置，重置落后落后告警状态
告警状态
        if alert_s        if alert_sent_beent_behindhind:
:
            logger            logger.info(f.info(f"本地"本地节点已追上节点已追上，高度，高度差: {height差: {height_diff}")
_diff}")
            send_tele            send_telegram_gram_alert(
alert(
                session,
                               session,
                f" f"✅ BSC✅ BSC本地节点已恢复正常\n本地节点已"
                f恢复正常\n""
                f"节点地址节点地址: {: {LOCALLOCAL_NODE_NODE_URL}\_URL}\n"
                f"本地n"
                f"本地高度:高度: {local {local_height}\_height}\n"
                fn"
                f"官方"官方高度:高度: {official {official_height}\_height}\n"
n"
                f                f"高度"高度差:差: {height {height_diff}\_diff}\n"
n"
                f                f"恢复"恢复时间:时间: {datetime {datetime.now()..now().strftimestrftime('%Y('%Y-%m-%d-%m-%d %H %H:%M:%S:%M')}"
:%S')}"
            )
        alert            )
_sent        alert_behind_sent_behind = False
    
    = False return True
    
    return True, True, True, no_change_count, no_change_count, alert, alert_sent_no_change_sent, alert_no_change, alert_sent_behind_sent


def_behind main():
    """


def main():
主监控    """主监控循环"""
    logger.info("循环"""
    logger.info("=" *=" * 60)
    60 logger.info)
    logger.info("BSC节点("BSC节点监控脚本监控脚本启动（启动（带官方带官方节点对比节点对比）")
）")
    logger    logger.info(f.info(f"本地"本地节点: {LOC节点:AL_N {LOCAL_NODE_URL}")
   ODE_URL logger.info}")
    logger.info(f"(f"官方节点官方节点: {: {OFFICOFFICIAL_NIAL_NODE_URLODE_URL}")
   }")
    logger.info logger.info(f"(f"检查间隔检查间隔: {: {CHECK_INCHECK_INTERVALTERVAL}秒")
}秒")
       logger.info logger.info(f"(f"高度落后高度落后告警告警阈值:阈值: {MAX {MAX_HEIGHT_HEIGHT_DI_DIFF}FF}个区块个区块")
   ")
    logger.info logger.info(f"(f"无变化无变化告告警阈值警阈值: : 连续{连续{MAX_NOMAX_NO_CHANGE_CHANGE_COUNT_COUNT}次}次无变化无变化")
    logger")
    logger.info("=".info("=" *  * 60)
60)
    
       
    #  # 创建带创建带重试机制的会话重试机制的会话
   
    session = session = create_session create_session_with_retry_with_retry()
    
()
    
    #    # 初始化 初始化监控状态监控状态
   
    last_local last_local_height:_height: Optional[int Optional[int] =] = None
 None
    no    no_change_count_change_count =  = 0
0
    alert    alert_sent_sent_no_change = False_no_change = False
   
    alert_s alert_sent_behind =ent_behind = False
    
 False
    
    #    # 启动 启动时测试时测试连接
连接
    logger    logger.info("测试节点.info("测试节点连接...连接...")
    test_local")
    test_local = get_block_height = get(session_block_height(session, LOCAL_NODE, LOCAL_URL,_NODE "本地_URL, "本地节点")
    test_official = get_block节点")
    test_official = get_block_height(s_height(session,ession, OFFIC OFFICIAL_NIAL_NODE_URLODE_URL, ", "官方节点官方节点")
    
")
    
    if    if test_local test_local is None is None:
       :
        logger.error logger.error("无法连接到本地("无法节点，连接到本地请检查节点，请检查节点配置")
       节点配置 send_")
       telegram send_telegram_alert(session_alert, f(session, f""❌ BSC监控❌ B启动失败SC监控启动失败\n无法\n无法连接到本地节点:连接到本地节点: {LOC {LOCAL_NAL_NODE_URL}")
       ODE_URL}")
        sys.exit sys.exit(1(1)
    
)
    
    if    if test_o test_official isfficial is None:
 None:
        logger        logger.warning.warning("无法("无法连接到官方连接到官方节点，节点，将只将只监控监控本地节点本地节点高度变化高度变化")
       ")
        send_ send_telegramtelegram_alert_alert(session, f(session, f"⚠"⚠️ B️ BSC监控SC监控启动警告启动警告\n无法\n无法连接到官方连接到官方节点:节点: {OFF {OFFICIALICIAL_NODE_NODE_URL}\_URL}\n将n将只监控只监控本地节点本地节点高度高度变化变化")
   ")
    else:
 else:
        logger        logger.info.info(f(f"初始"初始状态 - 状态 - 本地高度本地高度: {: {test_localtest_local}, }, 官方高度官方高度: {test_o: {test_official}")
fficial}")
    
    try:
        while    
    try:
        while True:
 True:
            #            # 获取 获取本地本地节点高度节点高度
            current_local
            current_local_height_height = get = get_block_height(session_block_height(session, LOCAL, LOCAL_NODE_NODE_URL,_URL, "本地 "本地节点")
节点")
            
            #             
            # 获取官方获取官方节点高度节点高度
            current_o
            current_official_heightfficial_height = get = get_block_height_block_height(session(session, OFF, OFFICIAL_NODEICIAL_NODE_URL,_URL, "官方 "官方节点")
            
           节点")
            
            #  # 检查节点检查节点健康状态健康状态
            should_
            should_continue,continue, need_sleep, no_change need_sleep, no_change_count, alert_s_count, alert_sent_noent_no_change,_change, alert_sent_be alert_sent_behind = check_node_hind = check_node_health(
health(
                session                session, current, current_local_height_local_height, current, current_official_official_height,
_height,
                last                last_local_height, no_local_height, no_change_count_change_count,
               ,
                alert_s alert_sent_noent_no_change,_change, alert_sent_be alert_sent_behind
hind
            )
            )
            
                       
            #  # 更新最后更新最后高度
高度
            if            if current_local_height is current_local_height is not None not None:
               :
                last_local_height = current_local_height
            
            if last_local_height = current_local_height
            
            if not should not should_continue_continue:
               :
                break
            
            # break
            
            # 等待下一次检查 等待下一次检查
           
            if need if need_sleep_sleep:
               :
                time.sleep time.sleep(CHECK(CHECK_INTER_INTERVAL)
            
   VAL)
            
    except Keyboard except KeyboardInterruptInterrupt:
       :
        logger.info logger.info("收到("收到中断信号中断信号，监控脚本退出，监控脚本退出")
       ")
        send_ send_telegramtelegram_alert_alert(session(session, ", "🛑 B🛑 BSC监控SC监控脚本已脚本已停止")
停止")
        sys        sys.exit(.exit(0)
0)
    except    except Exception as Exception as e:
 e:
        logger        logger.exception(f.exception(f"监控"监控循环发生循环发生未预期未预期异常:异常: {e {e}")
       }")
        send_ send_telegramtelegram_alert_alert(session, f(session, f"🔥"🔥 BSC BSC监控脚本监控脚本异常退出异常退出\n错误\n错误: {: {str(estr(e)}")
)}")
        sys        sys.exit(.exit(1)


1)


if __if __name__name__ == "__ == "__main__":
main__":
    main    main()