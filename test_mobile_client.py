import json
import asyncio
import websockets
import time
import random
import string

class TestMobileClient:
    def __init__(self, server_url):
        self.server_url = server_url
        self.device_name = "Test Samsung Galaxy S21"
        self.device_model = "Samsung SM-G991B"
        self.device_id = self._generate_device_id()
        
    def _generate_device_id(self):
        """Generate a mock Android device ID"""
        return ''.join(random.choices(string.ascii_lowercase + string.digits, k=16))
    
    async def connect_and_test(self):
        """Connect to server and send device identification"""
        try:
            print(f"[TEST_CLIENT] Connecting to {self.server_url}...")
            
            async with websockets.connect(self.server_url) as websocket:
                print(f"[TEST_CLIENT] Connected successfully!")
                
                # Send device identification
                device_info = {
                    'type': 'device_info',
                    'device_name': self.device_name,
                    'device_model': self.device_model,
                    'device_id': self.device_id,
                    'app_version': '1.0.0',
                    'timestamp': int(time.time() * 1000)
                }
                
                message = json.dumps(device_info)
                print(f"[TEST_CLIENT] Sending device identification: {message}")
                await websocket.send(message)
                
                # Wait for response and keep connection alive
                print(f"[TEST_CLIENT] Waiting for server response...")
                
                # Listen for messages for a few seconds
                try:
                    async with asyncio.timeout(10):
                        async for message in websocket:
                            print(f"[TEST_CLIENT] Received from server: {message}")
                except asyncio.TimeoutError:
                    print(f"[TEST_CLIENT] Connection timeout after 10 seconds")
                    
        except Exception as e:
            print(f"[TEST_CLIENT] Connection failed: {e}")

async def main():
    client = TestMobileClient("ws://192.168.1.2:8080")
    await client.connect_and_test()

if __name__ == "__main__":
    asyncio.run(main())
