
xml.tasks do
      xml.duetoday do
          @entry_items.each do |e| 
            xml.entry do
              xml.title(e.title)
              xml.notes(e.notes)
            end
          end
        end 
        xml.overdues do
          @overdue_entry_items.each do |e| 
            xml.entry do
              xml.title(e.title)
              xml.notes(e.notes)
            end
          end
        end 
end

