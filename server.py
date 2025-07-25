import asyncio
import websockets
import random

# 次の問題までの時間
time = 20

# 接続しているユーザーのリスト
connected_users = set()

# 質問データ
questions = [
    {
        "question": "Which is the largest planet in the solar system ?",
        "options": ["Earth", "Mars", "Jupiter", "Saturn"],
        "correct_index": 2
    },
    {
        "question": "What is the capital of Japan ?",
        "options": ["Osaka", "Nagoya", "Tokyo", "Fukuoka"],
        "correct_index": 2
    },
    {
        "question": "Where was Picasso born ?",
        "options": ["France", "Spain", "Italy", "Portugal"],
        "correct_index": 1
    }
]

async def counter_server(websocket):
    # 新しいクライアントが接続
    connected_users.add(websocket)
    print('ユーザーが接続しました。')

    # 接続数をすべてのクライアントに送信
    await notify_connected_users()

    try:
        # クライアントからのメッセージを待機
        async for message in websocket:
            await handle_message(message)
    except websockets.exceptions.ConnectionClosed:
        pass
    finally:
        # クライアントが切断した場合の処理
        connected_users.remove(websocket)
        print('ユーザーが切断しました。')
        await notify_connected_users()

async def handle_message(message):
    user_name, answer = message.split(':')
    await notify_all_users(f"{user_name} {answer}")

async def notify_all_users(message):
    # 全ユーザーにメッセージを送信
    if connected_users:
        await asyncio.gather(*(user.send(message) for user in connected_users))

async def notify_connected_users():
    # 接続数をカウント
    if connected_users:
        message = f'connected_users:{len(connected_users)}'
        await asyncio.gather(*(user.send(message) for user in connected_users))

async def send_question_to_all():
    if connected_users:
        # ランダムに質問を選ぶ
        question_data = random.choice(questions)
        question_message = f"{question_data['question']}\n" + \
                           "\n".join(question_data['options']) + "\n" + \
                           str(question_data['correct_index'])
        
        # すべてのユーザーに送信
        await asyncio.gather(*(user.send(question_message) for user in connected_users))

async def send_remaining_time():
    remaining_time = time
    while remaining_time >= 0:
        message = f'remaining_time:{remaining_time}'
        await notify_all_users(message)
        await asyncio.sleep(1)
        remaining_time -= 1

async def question_cycle():
    while True:
        await send_question_to_all()
        await send_remaining_time()

async def main():
    # サーバーを起動
    async with websockets.serve(counter_server, 'localhost', 8000):
        print('サーバーが起動しました。')
        # 質問のサイクルを開始
        asyncio.create_task(question_cycle())
        await asyncio.Future()

asyncio.run(main())
