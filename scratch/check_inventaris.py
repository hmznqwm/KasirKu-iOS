import os
from supabase import create_client, Client

url: str = "https://dozxsvxokczqettxszqq.supabase.co"
key: str = "sb_publishable_uyeylGxHMEbNwQnPFtD1Pg_ADz2ju3T"
supabase: Client = create_client(url, key)

try:
    response = supabase.table('inventaris').select('*').limit(1).execute()
    if len(response.data) > 0:
        print(response.data[0].keys())
    else:
        print("Table is empty but query succeeded. No schema info via select *.")
except Exception as e:
    print(e)
