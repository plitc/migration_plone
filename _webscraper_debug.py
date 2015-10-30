#!/usr/bin/env python
import requests, random
from bs4 import BeautifulSoup

url = "http://www.stura.htw-dresden.de"
doc = requests.get(url)
soup = BeautifulSoup(doc.text, 'html.parser')
rows = soup.select("table.wikitable.sortable tr")
choice = random.choice(rows)
print(choice.select("td i a")[0].text)

