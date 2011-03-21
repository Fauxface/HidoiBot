class ImageTagger < BotPlugin
    # SO MUCH SQL HAET
    def initialize
        extend HidoiSQL
        hsqlInitialize
        checkTagTables
        
        if !checkImageTable
            puts 'No image database was found'
        end
        
        # Required plugin stuff
        name = self.class.name
        @hook = 'tag'
        processEvery = false
        help = "Usage: #{@hook} (add <hash> <tag>|delete <hash> <tag>|search <tag>|view <hash>)\nFunction: Handles tags for ImageScraper images."
        super(name, @hook, processEvery, help)
    end

    def main(data)
        mode = arguments(data)[0]
        hash = arguments(data)[1]
        tags = arguments(data)[2] if arguments(data)[2] != nil
        
        case mode
            when 'add'
                return sayf(addTag(hash, tags))
            when /(remove|delete)/
                return sayf(delTag(hash, tags))
            when /(search|find)/
                tag = arguments(data)[1]
                return sayf("Hashes: #{findTag(tag).join(', ')}\nUse recall hash <hash> to view.")
            when /(view|list)/
                return sayf(viewTag(hash))
            else
                return nil
        end
    rescue => e
        handleError(e)
        return nil
    end
    
    def addTag(hash, tags)
        tags = tags.split(',')
        
        tags.each { |i|
            i.gsub!(' ','')
        }
        
        if tags.size > 1
            # Multiple tags
            tags.each { |tag|
                addTagSql(hash, tag)
            }
        elsif tags.size == 1
            # Single tag
            addTagSql(hash, tags[0])
        end
    end
    
    def addTagSql(hash, tag)
        if silentSql("SELECT rowid FROM tag WHERE name='#{tag}'")[0] == nil        
            # If this tag does not exist yet
            sql ("
                INSERT INTO tag (
                    name
                ) VALUES (
                    '#{tag}'
                )
            ")
        end
        
        # Get tag's rowid
        tagId = sql("SELECT rowid FROM tag WHERE name='#{tag}'")[0][0]
        imageId = sql("SELECT rowid FROM image WHERE sha256='#{hash}'")[0][0]
        
        # Link tag to image
        if silentSql("SELECT rowid FROM image_tag WHERE tag_id='#{tagId}' AND image_id='#{imageId}'")[0] == nil   
            # If tag doesn't already exist
            sql ("
                INSERT INTO image_tag (
                    image_id,
                    tag_id
                ) VALUES (
                    '#{imageId}',
                    '#{tagId}'
                )
            ")
        else
            return 'This tag already exists for this image.'
        end
        
        return 'Tag added.'
    end
    
    def delTag(hash, tag)
        imageId = sql("SELECT rowid FROM image WHERE sha256='#{hash}'")[0][0]
        tagId = sql("SELECT rowid FROM tag WHERE name='#{tag}'")[0][0]
        sql("DELETE FROM image_tag WHERE image_id='#{imageId}' AND tag_id='#{tagId}'")
        return 'Tag deleted, even if it wasn\'t there. Tag deleted hard.'
    end
    
    def viewTag(hash)
        tagIds = Array.new
        tags = Array.new
        imageId = sql("SELECT rowid FROM image WHERE sha256='#{hash}'")[0][0]
        tagIds = sql("SELECT tag_id FROM image_tag WHERE image_id='#{imageId}'")
        
        tagIds.each { |tagId|
            tags.push(sql("SELECT name FROM tag WHERE rowid='#{tagId[0]}'")[0])
        }
        
        return tags.join(', ')
    end
    
    def findTag(tag)
        imageHashes = Array.new
        tagId = sql("SELECT rowid FROM tag WHERE name='#{tag}'")[0][0]
        imageRowIds = sql("SELECT image_id FROM image_tag WHERE tag_id='#{tagId}'")
        
        puts imageRowIds.class
        puts imageRowIds.inspect
        
        if imageRowIds.class == Array
            imageRowIds.each{ |imageRowId|
                imageHashes.push(sql("SELECT sha256 FROM image WHERE rowid='#{imageRowId[0]}'")[0][0])
            }
        else
            imageHashes.push(sql("SELECT sha256 FROM image WHERE rowid='#{imageRowIds[0]}'")[0][0])
        end
        
        return imageHashes
    end
    
    def checkImageTable
         if silentSql("SELECT name FROM sqlite_master WHERE type='table' AND name='image'")[0] != nil
            return true
         else
            return false
        end
    end
    
    def checkTagTables
        # Table image_tag
        silentSql ('
            CREATE TABLE IF NOT EXISTS tag
            (
                name string NOT NULL
            )
        ')
        
        # Table image_tag - this links tags to images
        silentSql ('
            CREATE TABLE IF NOT EXISTS image_tag
            (
                image_id integer NOT NULL,
                tag_id integer NOT NULL
            )
        ')
    end
end