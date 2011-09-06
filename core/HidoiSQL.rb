# Ng Guoyou
# HidoiSQL.rb
# SQLite interface for HidoiBot
# I should have made this a Class instead

module HidoiSQL
  require 'sqlite3'

  def hsqlInitialize()
    @dbLocation = 'db'
    @dbName = 'hidoidb.db'

    if File.file?("#{@dbLocation}/#{@dbName}") == false
      puts "Creating new database."
      File.open("#{@dbLocation}/#{@dbName}", 'a+')
    end

    # Open the db
    @db = SQLite3::Database.new("#{@dbLocation}/#{@dbName}")
  end

  def sql(query)
    puts query
    return sqlQuery(query)
  rescue => e
    handleSqlError(e)
  end

  def silentSql(query)
    return sqlQuery(query)
  rescue => e
    handleSqlError(e)
  end

  def sqlQuery(query)
    return @db.execute(query)
  rescue => e
    handleSqlError(e)
  end

  def handleSqlError(e)
    puts e
    puts e.backtrace.join("\n")
  end
end