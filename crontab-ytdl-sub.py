# 请预先安装如下依赖
# pip3 install mysql-connector-python
# subscriptions-clasic.yaml为订阅模板文件
# config-1years.yaml 为配置模板文件
# 注意：如果订阅下载最近多长时间的视频，那么配置模板中和订阅模板中的download_range值要一致[1weeks为最近一周,1months为最近一个月,1years为最近一年]，否则会报错。
import mysql.connector
import os

# 连接 MySQL 数据库
db = mysql.connector.connect(
    host="",
    user="",
    password="",
    database=""
)
# 创建游标对象
cursor = db.cursor()

# 查询数据库
query = "SELECT chinesename, name, url, timerange FROM list"
cursor.execute(query)
results = cursor.fetchall()
# 循环遍历结果，执行任务
for chinesename, name, url, timerange in results:
    if timerange == "1years":
        query1 = "UPDATE `ytdl-sub`.`list` SET `timerange` = '1weeks' WHERE `name` = '%s'"%(name,)
        try:
            db.ping(reconnect=True)
            cursor.execute(query1)
            db.commit()
        except Exception as e:
            print(e)
cursor.close()
db.close()
# 循环遍历结果，执行任务
for chinesename, name, url, timerange in results:
    # 定义新的配置文件名格式
    config_file_name = f"subscriptions-{name}.yaml"
    if timerange == "1years":
        os.system(f"cp subscriptions-clasic.yaml {config_file_name}")
        os.system(f'sed -i "s/laogao/{name}/" {config_file_name}')
        os.system(f'sed -i "s/老高與小茉/{chinesename}/" {config_file_name}')
        os.system(f'sed -i "s/1weeks/1years/" {config_file_name}')
        os.system(f'sed -i "s%https://www.youtube.com/@xxx/videos%{url}%" {config_file_name}')
        os.system(f"ytdl-sub --config=/config/config-1years.yaml sub /config/{config_file_name}")
        os.system(f"rm {config_file_name}")

    else:
        os.system(f"cp subscriptions-clasic.yaml {config_file_name}")
        os.system(f'sed -i "s/laogao/{name}/" {config_file_name}')
        os.system(f'sed -i "s/老高與小茉/{chinesename}/" {config_file_name}')
        os.system(f'sed -i "s%https://www.youtube.com/@xxx/videos%{url}%" {config_file_name}')
        os.system(f"ytdl-sub --config=/config/config-dianxixiaoge.yaml sub /config/{config_file_name}")
        os.system(f"rm {config_file_name}")

# 关闭游标和数据库连接
os.system(f"gclone copy /tv_shows/ SA:影视剧/油管专辑 --drive-server-side-across-configs --transfers=8 -P")
os.system(f"cd /tv_shows && rm ./* -rf")
