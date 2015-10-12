Telegram = require('telegram-bot')
sqlite = require('sqlite3')

blacklist = ["help", "add", "list", "stats"]

db_file = "kindergarten.db"
db = new sqlite.Database db_file
db.run "CREATE TABLE kindergarten (text TEXT(255), chat TEXT(25), command TEXT(25), UNIQUE(chat, command) ON CONFLICT REPLACE);",
(exeErr) ->
  console.log exeErr if exeErr
db.close()

tg = new Telegram(process.env.TELEGRAM_BOT_TOKEN)
tg.on 'message', (msg) ->
  return unless msg.text
  console.log msg.chat.id+": "+msg.text
  send = (message) ->
    tg.sendMessage
      text: message
      reply_to_message_id: msg.message_id
      chat_id: msg.chat.id

  if msg.text.match(/^\/(help|start)/i)
    send "add <new command> <text> - Add a new command\n"+
      "list [<page number>] - List known commands\n"+
      "help - Help page"
  else if msg.text.match(/^\/add.+/i)
    [_, command, text] = msg.text.match(/^\/add\s(\w+?)\s(.+?)$/)
    # check on existence
    unless command? and text?
      return
    # blacklist
    if command in blacklist
      send command+" is black-listed. Abort!"
      return
    db = new sqlite.Database db_file
    db.run "INSERT INTO kindergarten (chat, command, text) VALUES ('"+
      msg.chat.id+"', '"+command+"', '"+text+"')"
    db.close()
    send "New command '"+command+"' was added!"
  else if msg.text.match(/^\/list/i)
    offset = 0
    limit = 3 # TODO hard-coded
    [_, page] = msg.text.match(/^\/list\s(\d+)$/) or [null, 1]
    offset = (page * limit) - limit
    send "Page "+page+". Increase with /list <number>"
    db = new sqlite.Database db_file
    db.each "SELECT command, text FROM kindergarten WHERE chat LIKE '"+
      msg.chat.id+"' LIMIT "+limit+" OFFSET "+offset,
    (exeErr, row) ->
      throw exeErr if exeErr
      send row.command+": "+row.text
    db.close()
  else if msg.text.match(/^\/stats$/i)
    db.each "SELECT count(command) FROM kindergarten WHERE chat LIKE '"+msg.chat.id+"'",
    (exeErr, cnt) ->
      throw exeErr if exeErr
      send "There are/is "+cnt+" command(s) available!"
    db.close()
  else if msg.text.match(/^\//)
    [_, command] = msg.text.match(/^\/(\w+)$/)
    text = msg.text.replace('/','')
    db = new sqlite.Database db_file
    db.each "SELECT text FROM kindergarten WHERE command LIKE '"+
      command+"' AND chat LIKE '"+msg.chat.id+"' LIMIT 1",
    (exeErr, row) ->
      throw exeErr if exeErr
      send row.text
    db.close()

tg.start()
