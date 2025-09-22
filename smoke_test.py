import requests

def main():
    url = 'http://localhost:8000/generate'
    data = {'prompt': 'Hello from smoke test'}
    try:
        r = requests.post(url, json=data, timeout=10)
        print('Status:', r.status_code)
        print('Body:', r.text)
    except Exception as e:
        print('Error:', e)

if __name__ == '__main__':
    main()
