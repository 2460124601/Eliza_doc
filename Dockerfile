FROM ruby:3.3

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

RUN mkdir -p /app/public /app/tmp

EXPOSE 8080

CMD ["sh", "-c", "bundle exec ruby build.rb && ruby serve.rb"]
