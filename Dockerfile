FROM python:2.7.10-wheezy
RUN pip install Flask flask-mysqldb redis
COPY src/ /app/

EXPOSE "80"
WORKDIR /app
CMD ["python", "app.py"]