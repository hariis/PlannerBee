module Schedulehelper

#def update_remind_once_fields
#	if attribute_changed?(self.freq_type) || attribute_changed?(self.start_dt)
#		set_remind_once_fields
#	end
#end
def set_remind_once_fields
	
	
    case (self.freq_type)
        
		when 0,12  #Not Scheduled
				self.start_dt_tm = TzTime.at(Date.parse("1970-01-01")).at_beginning_of_day.utc
				self.freq_interval = 0
				self.end_dt_tm = self.start_dt_tm
				
		when 1    #Later Today
				self.start_dt_tm = TzTime.now.at_beginning_of_day.utc  #00:00
				self.freq_interval = 1
				self.end_dt_tm = TzTime.now.at_beginning_of_day.tomorrow.ago(60).utc #23:59
		
		when 11    #Pick a date
                                self.start_dt_tm = TzTime.at(start_dt_tm).at_beginning_of_day.utc
				self.freq_interval = 1
				self.end_dt_tm = TzTime.at(start_dt_tm).at_beginning_of_day.tomorrow.ago(60).utc #23:59
				
		when 2   #Tomorrow
				self.start_dt_tm = TzTime.now.tomorrow.at_beginning_of_day.utc
				self.freq_interval = 1
				self.end_dt_tm = TzTime.now.tomorrow.at_beginning_of_day.tomorrow.ago(60).utc #23:59
				
		when 3   #This Friday
				  
				start_dt = TzTime.now.to_date
				diff = 5 - start_dt.wday
                                case diff
                                when 0 #On a friday - Move to next friday
                                    start_dt = TzTime.now.to_date + 7
                                when -1 # on a Saturday
                                    start_dt = TzTime.now.to_date + 6
                                when 1,2,3,4,5
                                    start_dt = TzTime.now.to_date + diff
                                end                       
                                self.start_dt_tm = TzTime.at(start_dt).at_beginning_of_day.utc
				self.end_dt_tm = TzTime.at(start_dt).at_beginning_of_day.tomorrow.ago(60).utc #23:59
				
		when 4   #This Weekend  - Schedule it for this Saturday
				  
				start_dt = TzTime.now.to_date
				diff = 6 - start_dt.wday
                                case diff
                                when 0 #On a Sat - Move to next Sat
                                    start_dt = TzTime.now.to_date + 7
                                
                                when 1,2,3,4,5,6
                                    start_dt = TzTime.now.to_date + diff
                                end                       

				self.start_dt_tm = TzTime.at(start_dt).at_beginning_of_day.utc
				self.end_dt_tm = TzTime.at(start_dt).at_beginning_of_day.tomorrow.ago(60).utc #23:59
		when 5   #Next Week - Move to Monday of next week
				 
				start_dt = TzTime.now.to_date
				diff =  1 - start_dt.wday
                                start_dt = TzTime.now.to_date + diff + 7
                                
                                self.start_dt_tm = TzTime.at(start_dt).at_beginning_of_day.utc
				self.end_dt_tm = TzTime.at(start_dt).at_beginning_of_day.tomorrow.ago(60).utc #23:59
   
    end
  end

def self.GetDatesFor(entry)
      @dates =[]
      start_dt = TzTime.zone.utc_to_local(entry.start_dt_tm).to_date
      end_dt = TzTime.zone.utc_to_local(entry.end_dt_tm).to_date
      case (entry.freq_type)
                  
                when 0,1,3,4,5,11,12    #Not scheduled, Later Today, This Friday, This Sat, Next week
                  
                          @dates << start_dt
                  
                when 2   #Tomorrow
                          @dates << start_dt 
                          
                #when 3   #This Friday
                #when 4   #This Weekend         
                #when 5   #Next Week        
                when 6    #Daily
                          #Step 1: Come up with the adder
                          adder = entry.freq_interval

                          #Step 2: Figure out the Start Date										
                          actualstartDate = start_dt
                          
                          #Step 3: Calculate the rest of the dates
                         while (actualstartDate <= end_dt)
                            @dates << actualstartDate
                            actualstartDate = actualstartDate + adder
                         end	
                when 7         #Weekly
                          #Step 1: Come up with the adder
                          adder = entry.freq_interval * 7

                          #Step 2: Figure out the Start Date										
                          actualstartDate = start_dt
                          actualstartDates = []
                          vals = ExtractFreqIntQualIntoArr(entry.freq_interval_qual, false)
                          if (!IsDOWInList(actualstartDate.wday,entry.freq_interval_qual) || vals.length != 1)
                            #if the dow is not in list OR if the list has more than one item
                            actualstartDates = GetFirstDates(actualstartDate,entry.freq_interval_qual  )
                          else
                             #if the dow is in list and list has just one skip
                             actualstartDates = [actualstartDate]
                          end
                          #Step 3: Calculate the rest of the dates
                          
                          actualstartDates.each do |newStartDate|
                                 while (newStartDate <= end_dt)
                                        @dates << newStartDate
                                        newStartDate = newStartDate + adder
                                  end
                          end
                                                   
                when 8              #Monthly_By_Date
                          #Step 1: Come up with the adder
                          adder = entry.freq_interval

                          #Step 2: Figure out the Start Date										
                          actualstartDate = start_dt
                          actualstartDates = []
                          vals = ExtractFreqIntQualIntoArr(entry.freq_interval_qual,true)
                          if (!IsDateInList(actualstartDate.day,entry.freq_interval_qual) || vals.length != 1)
                                actualstartDates = GetFirstDates_MonthlyByDate(actualstartDate,entry.freq_interval_qual)	
                          else
                               #if the dow is in list and list has just one skip
                               actualstartDates = [actualstartDate]                                  
                          end
                          #Step 3: Calculate the rest of the dates
                       
                          actualstartDates.each do |newStartDate|
                             while (newStartDate <= end_dt)
                                    @dates << newStartDate
                                    newStartDate = newStartDate >> adder
                              end
                          end
                when 9            #Monthly_By_Day
                          #Step 1: Come up with the adder
                          adder = entry.freq_interval

                          #Step 2: Figure out the Start Date										
                          actualstartDate = start_dt
                          actualstartDates = []
                          vals = ExtractFreqIntQualIntoArr(entry.freq_interval_qual,false)
                          if vals.length > 0 then
                              actualstartDates = GetFirstDates_OrdinalDOW(actualstartDate,entry.freq_interval_qual)	
                           end                                                         
                          
                          #Step 3: Calculate the rest of the dates
                          actualstartDates.sort.collect do |newStartDate|
                          nextDate = newStartDate[1]
                          while (nextDate <= end_dt)
                                  @dates << nextDate
                                  nextDate = nextDate >> adder
                                  nextDate = GetDateByOrdinalDOW(nextDate, newStartDate[0])
                            end
                          end
                        
                when 10                 #Yearly
                          #Step 1: Come up with the adder
                          adder = entry.freq_interval * 12

                          #Step 2: Figure out the Start Date										
                          actualstartDate = start_dt
                          
                          #Step 3: Calculate the rest of the dates
                         while (actualstartDate <= end_dt)
                            @dates << actualstartDate
                            actualstartDate = actualstartDate >> adder
                          end
                        end
      return @dates
  end
  def self.GetDatesUpToToday(entry)
      @dates =[]
      #Convert the start and end dates to local time to come up with the scheduled dates
      start_dt = TzTime.zone.utc_to_local(entry.start_dt_tm).to_date
      end_dt = TzTime.now.utc <= entry.end_dt_tm ? TzTime.now.to_date : TzTime.zone.utc_to_local(entry.end_dt_tm).to_date
      case (entry.freq_type)
                  
                when 0,1,2,3,4,5,11,12    #Not scheduled, Later Today, Tomorrow, This Friday, This Sat, Next week
                  
                          @dates << start_dt if start_dt <= end_dt
                          return @dates
                            
                when 6    #Daily
                          #Step 1: Come up with the adder
                          adder = entry.freq_interval

                          #Step 2: Figure out the Start Date										
                          actualstartDate = start_dt
                          
                          #Step 3: Calculate the rest of the dates
                         while (actualstartDate <= end_dt)
                            @dates << actualstartDate
                            actualstartDate = actualstartDate + adder
                         end	
                when 7         #Weekly
                          #Step 1: Come up with the adder
                          adder = entry.freq_interval * 7

                          #Step 2: Figure out the Start Date										
                          actualstartDate = start_dt
                          actualstartDates = []
                          vals = ExtractFreqIntQualIntoArr(entry.freq_interval_qual, false)
                          if (!IsDOWInList(actualstartDate.wday,entry.freq_interval_qual) || vals.length != 1)
                            #if the dow is not in list OR if the list has more than one item
                            actualstartDates = GetFirstDates(actualstartDate,entry.freq_interval_qual  )
                          else
                             #if the dow is in list and list has just one skip
                             actualstartDates = [actualstartDate]
                          end
                          #Step 3: Calculate the rest of the dates
                          
                          actualstartDates.each do |newStartDate|
                                 while (newStartDate <= end_dt)
                                        @dates << newStartDate
                                        newStartDate = newStartDate + adder
                                  end
                          end
                                                   
                when 8              #Monthly_By_Date
                          #Step 1: Come up with the adder
                          adder = entry.freq_interval

                          #Step 2: Figure out the Start Date										
                          actualstartDate = start_dt
                          actualstartDates = []
                          vals = ExtractFreqIntQualIntoArr(entry.freq_interval_qual,true)
                          if (!IsDateInList(actualstartDate.day,entry.freq_interval_qual) || vals.length != 1)
                                actualstartDates = GetFirstDates_MonthlyByDate(actualstartDate,entry.freq_interval_qual)	
                          else
                               #if the dow is in list and list has just one skip
                               actualstartDates = [actualstartDate]                                  
                          end
                          #Step 3: Calculate the rest of the dates
                       
                          actualstartDates.each do |newStartDate|
                             while (newStartDate <= end_dt)
                                    @dates << newStartDate
                                    newStartDate = newStartDate >> adder
                              end
                          end
                when 9            #Monthly_By_Day
                          #Step 1: Come up with the adder
                          adder = entry.freq_interval

                          #Step 2: Figure out the Start Date										
                          actualstartDate = start_dt
                          actualstartDates = []
                          vals = ExtractFreqIntQualIntoArr(entry.freq_interval_qual,false)
                          if vals.length > 0 then
                              actualstartDates = GetFirstDates_OrdinalDOW(actualstartDate,entry.freq_interval_qual)	
                           end                                                         
                          
                          #Step 3: Calculate the rest of the dates
                          actualstartDates.sort.collect do |newStartDate|
                          nextDate = newStartDate[1]
                          while (nextDate <= end_dt)
                                  @dates << nextDate
                                  nextDate = nextDate >> adder
                                  nextDate = GetDateByOrdinalDOW(nextDate, newStartDate[0])
                            end
                          end
                        
                when 10                 #Yearly
                          #Step 1: Come up with the adder
                          adder = entry.freq_interval * 12

                          #Step 2: Figure out the Start Date										
                          actualstartDate = start_dt
                          
                          #Step 3: Calculate the rest of the dates
                         while (actualstartDate <= end_dt)
                            @dates << actualstartDate
                            actualstartDate = actualstartDate >> adder
                          end
                        end
      return @dates
  end
  def self.get_future_scheduled_dates(entry)
      @dates =[]
      return @dates if TzTime.now.utc > entry.end_dt_tm
      #Pull Scheduled dates starting today until the end date of the tasks
      start_dt =  TzTime.now.to_date + 1  #Starting tomorrow
      end_dt =  TzTime.zone.utc_to_local(entry.end_dt_tm).to_date
      case (entry.freq_type)
                  
                when 0,1,2,3,4,5,11,12    #Not scheduled, Later Today, Tomorrow, This Friday, This Sat, Next week
                  
                          @dates << start_dt if start_dt <= end_dt
                          return @dates
                            
                when 6    #Daily
                          #Step 1: Come up with the adder
                          adder = entry.freq_interval

                          #Step 2: Figure out the Start Date										
                          if entry.freq_interval != 1 then                           
                             actualstartDate = TzTime.zone.utc_to_local(entry.start_dt_tm).to_date                              
                          else
                            actualstartDate = start_dt
                          end
                          
                          #Step 3: Calculate the rest of the dates
                         while (actualstartDate <= end_dt)
                            @dates << actualstartDate
                            actualstartDate = actualstartDate + adder
                         end	
                when 7         #Weekly
                          #Step 1: Come up with the adder
                          adder = entry.freq_interval * 7

                          #Step 2: Figure out the Start Date										
                          if entry.freq_interval != 1 then                           
                             actualstartDate = TzTime.zone.utc_to_local(entry.start_dt_tm).to_date                              
                          else
                            actualstartDate = start_dt
                          end
			  
                          actualstartDates = []
                          vals = ExtractFreqIntQualIntoArr(entry.freq_interval_qual, false)
                          if (!IsDOWInList(actualstartDate.wday,entry.freq_interval_qual) || vals.length != 1)
                            #if the dow is not in list OR if the list has more than one item
                            actualstartDates = GetFirstDates(actualstartDate,entry.freq_interval_qual  )
                          else
                             #if the dow is in list and list has just one skip
                             actualstartDates = [actualstartDate]
                          end
                          #Step 3: Calculate the rest of the dates
                          
                          actualstartDates.each do |newStartDate|
                                 while (newStartDate <= end_dt)
                                        @dates << newStartDate
                                        newStartDate = newStartDate + adder
                                  end
                          end
                                                   
                when 8              #Monthly_By_Date
                          #Step 1: Come up with the adder
                          adder = entry.freq_interval

                          #Step 2: Figure out the Start Date										
                          if entry.freq_interval != 1 then                           
                             actualstartDate = TzTime.zone.utc_to_local(entry.start_dt_tm).to_date                              
                          else
                            actualstartDate = start_dt
                          end
			  
                          actualstartDates = []
                          vals = ExtractFreqIntQualIntoArr(entry.freq_interval_qual,true)
                          if (!IsDateInList(actualstartDate.day,entry.freq_interval_qual) || vals.length != 1)
                                actualstartDates = GetFirstDates_MonthlyByDate(actualstartDate,entry.freq_interval_qual)	
                          else
                               #if the dow is in list and list has just one skip
                               actualstartDates = [actualstartDate]                                  
                          end
                          #Step 3: Calculate the rest of the dates
                       
                          actualstartDates.each do |newStartDate|
                             while (newStartDate <= end_dt)
                                    @dates << newStartDate
                                    newStartDate = newStartDate >> adder
                              end
                          end
                when 9            #Monthly_By_Day
                          #Step 1: Come up with the adder
                          adder = entry.freq_interval

                          #Step 2: Figure out the Start Date										
                          if entry.freq_interval != 1 then                           
                             actualstartDate = TzTime.zone.utc_to_local(entry.start_dt_tm).to_date                              
                          else
                            actualstartDate = start_dt
                          end
			  
                          actualstartDates = []
                          vals = ExtractFreqIntQualIntoArr(entry.freq_interval_qual,false)
                          if vals.length > 0 then
                              actualstartDates = GetFirstDates_OrdinalDOW(actualstartDate,entry.freq_interval_qual)	
                           end                                                         
                          
                          #Step 3: Calculate the rest of the dates
                          actualstartDates.sort.collect do |newStartDate|
                          nextDate = newStartDate[1]
                          while (nextDate <= end_dt)
                                  @dates << nextDate
                                  nextDate = nextDate >> adder
                                  nextDate = GetDateByOrdinalDOW(nextDate, newStartDate[0])
                            end
                          end
                        
                when 10                 #Yearly
                          #Step 1: Come up with the adder
                          adder = entry.freq_interval * 12

                          #Step 2: Figure out the Start Date										
                          if entry.freq_interval != 1 then                           
                             actualstartDate = TzTime.zone.utc_to_local(entry.start_dt_tm).to_date                              
                          else
                            actualstartDate = start_dt
                          end
                          
                          #Step 3: Calculate the rest of the dates
                         while (actualstartDate <= end_dt)
                            @dates << actualstartDate
                            actualstartDate = actualstartDate >> adder
                          end
                        end
      return @dates
  end
  #This method is purely date based, it does not care about the time and hence timezone
  #So providing local date for today provides the direct result
  def self.IsEntryDueOn(entry,anydate)
      @dates =[]
      start_dt = anydate
      end_dt = anydate
      case (entry.freq_type)
                  
                when 0,1,2,3,4,5,11,12    #Not scheduled, Later Today, Tomorrow, This Friday, This Sat, Next week
                  
                        entry_start_dt = TzTime.zone.utc_to_local(entry.start_dt_tm).to_date  
                        return entry_start_dt == anydate
                            
                when 6    #Daily
                          #Step 1: Come up with the adder
                          adder = entry.freq_interval

                          #Step 2: Figure out the Start Date										
                          if entry.freq_interval != 1 then                           
                             actualstartDate = TzTime.zone.utc_to_local(entry.start_dt_tm).to_date                              
                          else
                            actualstartDate = start_dt
                          end
                          
                          #Step 3: Calculate the rest of the dates
                         while (actualstartDate <= end_dt)
                            @dates << actualstartDate
                            actualstartDate = actualstartDate + adder
                         end	
                when 7         #Weekly
                          #Step 1: Come up with the adder
                          adder = entry.freq_interval * 7

                          #Step 2: Figure out the Start Date
                          if entry.freq_interval != 1 then                           
                             actualstartDate = TzTime.zone.utc_to_local(entry.start_dt_tm).to_date                              
                          else
                            actualstartDate = start_dt
                          end                   
      
                          actualstartDates = []
                          vals = ExtractFreqIntQualIntoArr(entry.freq_interval_qual, false)
                          if (!IsDOWInList(actualstartDate.wday,entry.freq_interval_qual) || vals.length != 1)
                            #if the dow is not in list OR if the list has more than one item
                            actualstartDates = GetFirstDates(actualstartDate,entry.freq_interval_qual  )
                          else
                             #if the dow is in list and list has just one skip
                             actualstartDates = [actualstartDate]
                          end
                          #Step 3: Calculate the rest of the dates
                          
                          actualstartDates.each do |newStartDate|
                                 while (newStartDate <= end_dt)
                                        @dates << newStartDate
                                        newStartDate = newStartDate + adder
                                  end
                          end
                                                   
                when 8              #Monthly_By_Date
                          #Step 1: Come up with the adder
                          adder = entry.freq_interval

                          #Step 2: Figure out the Start Date										
                          if entry.freq_interval != 1 then                           
                             actualstartDate = TzTime.zone.utc_to_local(entry.start_dt_tm).to_date                              
                          else
                            actualstartDate = start_dt
                          end 
                          actualstartDates = []
                          vals = ExtractFreqIntQualIntoArr(entry.freq_interval_qual,true)
                          if (!IsDateInList(actualstartDate.day,entry.freq_interval_qual) || vals.length != 1)
                                actualstartDates = GetFirstDates_MonthlyByDate(actualstartDate,entry.freq_interval_qual)	
                          else
                               #if the dow is in list and list has just one skip
                               actualstartDates = [actualstartDate]                                  
                          end
                          #Step 3: Calculate the rest of the dates
                       
                          actualstartDates.each do |newStartDate|
                             while (newStartDate <= end_dt)
                                    @dates << newStartDate
                                    newStartDate = newStartDate >> adder
                              end
                          end
                when 9            #Monthly_By_Day
                          #Step 1: Come up with the adder
                          adder = entry.freq_interval

                          #Step 2: Figure out the Start Date										
                          if entry.freq_interval != 1 then                           
                             actualstartDate = TzTime.zone.utc_to_local(entry.start_dt_tm).to_date                              
                          else
                            actualstartDate = start_dt
                          end 
                          actualstartDates = []
                          vals = ExtractFreqIntQualIntoArr(entry.freq_interval_qual,false)
                          if vals.length > 0 then
                              actualstartDates = GetFirstDates_OrdinalDOW(actualstartDate,entry.freq_interval_qual)	
                           end                                                         
                          
                          #Step 3: Calculate the rest of the dates
                          actualstartDates.sort.collect do |newStartDate|
                          nextDate = newStartDate[1]
                          while (nextDate <= end_dt)
                                  @dates << nextDate
                                  nextDate = nextDate >> adder
                                  nextDate = GetDateByOrdinalDOW(nextDate, newStartDate[0])
                            end
                          end
                        
                when 10                 #Yearly
                          #Step 1: Come up with the adder
                          adder = entry.freq_interval * 12

                          #Step 2: Figure out the Start Date										
                          if entry.freq_interval != 1 then                           
                             actualstartDate = TzTime.zone.utc_to_local(entry.start_dt_tm).to_date                              
                          else
                            actualstartDate = start_dt
                          end 
                          
                          #Step 3: Calculate the rest of the dates
                         while (actualstartDate <= end_dt)
                            @dates << actualstartDate
                            actualstartDate = actualstartDate >> adder
                          end
                        end
      return is_item_in_list(@dates,start_dt)
  end

def self.GetFirstDates(currdate, dowlist)
          newStartDates = []
          vals = ExtractFreqIntQualIntoArr(dowlist,false)
          while (vals.length != 0)
          
                convertToDOW = vals[-1]
                
                vals.sort.collect{|val| if val >= currdate.wday : convertToDOW = val end }
                currdateDOW =  currdate.wday 
                if (convertToDOW >= currdateDOW)
                  newStartDates << currdate + (convertToDOW- currdateDOW)
                else 
                  newStartDates << currdate + (7 - (currdateDOW- convertToDOW))
                end
                vals.delete(convertToDOW)
              end
              
        return newStartDates
    end
    
def self.GetFirstDates_MonthlyByDate(currdate, datelist)
      newStartDates = []
        vals = ExtractFreqIntQualIntoArr(datelist,true)
        while (vals.length != 0)
        
              convertToDate = vals[-1]
              
              vals.sort.collect{|val| if val >= currdate.day : convertToDate = val end }
              currDay =  currdate.day 
              if (convertToDate >= currDay)
                  newStartDates << currdate + (   convertToDate - currDay)
              else 
                  currdate = currdate >> 1
                  subInterval =  currDay - convertToDate
                   
                  currdate  = currdate - subInterval
                  newStartDates << currdate
              end
              vals.delete(convertToDate)
            end
            
      return newStartDates
end
    
def self.GetFirstDates_OrdinalDOW(currdate,ordDOWlist)
          newStartDates = {}
          vals = ExtractFreqIntQualIntoArr(ordDOWlist, false)
          if (vals.length != 0)
               vals.sort.each do|val|  
                
                      firstdate = GetDateByOrdinalDOW(currdate, val)
                      if firstdate >= currdate then
                          newStartDates[val] = firstdate
                      else
                          newStartDates[val] = GetDateByOrdinalDOW(currdate >> 1, val)
                      end
                
                end
          end
              
        return newStartDates  
      
    end
#Given an ordinal DOW (1st Sunday) and a month and a year, return the corresponding DATE
def self.GetDateByOrdinalDOW(currdate, idxDay)
			requestedDOW = idxDay.remainder(7)
			case (idxDay)
			
				when 0..6	#1st Sunday - 1st Saturday
                    return GetDateByDOW(1, currdate, idxDay)
					

				when 7..13	  #2nd Sunday - 2nd Saturday
                    return GetDateByDOW(8, currdate, idxDay)
					

				when 14..20: 	#3rd Sunday - 3rd Saturday
                    return GetDateByDOW(15, currdate, idxDay)
					
				when 21..27:   #4th Sunday - 4th Saturday
                    return GetDateByDOW(22, currdate, idxDay)
					
				when 28..34:	#Last Sunday - Last Saturday
					#Get the last 7 days of the month
          endLastWeek = currdate.days_in_month
					beginLastWeek = endLastWeek - 6
                    return GetDateByDOW(beginLastWeek, currdate, idxDay)
					
			end
			return currdate
		end
 #Zeroes in on the exact date 
def self.GetDateByDOW(weekStartDt, currdate, ordinalDOW)
           requestedDOW = ordinalDOW.remainder(7)
          weekEndDt = weekStartDt + 6
          for  j in (weekStartDt..weekEndDt)
          
              thedate = Date.parse("#{currdate.month}/#{j}/#{currdate.year}")
              if (thedate.wday == requestedDOW)
                    return thedate
              end
          end
end

 def self.IsDOWInList(checkwday, dowlist)
    vals = ExtractFreqIntQualIntoArr(dowlist,false)

    vals.sort.collect{|val| if val == checkwday : return true end }

    return false
  end
 def self.IsDateInList(checkdate, datelist)
        vals = ExtractFreqIntQualIntoArr(datelist,true)

        vals.sort.collect{|val| if val == checkdate : return true end }

        return false
 end
 def self.ExtractFreqIntQualIntoArr(freqintquallist,normalized)
        vals = []
        if normalized : factor = 1 else factor = 0 end
        34.downto(0) do |n| 
           if freqintquallist[n] == 1 then
              vals << (n + factor)
           end
        end
    return vals
 end
 def self.is_item_in_list(list, item)
          if list != nil then
            list.each do |p|
                  return true if p == item
            end
          end
          return false
  end     
      FREQ_TYPES = [
      ["1", "Later Today"],
      ["2", "Tomorrow"],
      ["3", "Coming Friday"],
      ["4", "Coming Weekend"],
      ["5", "Next Week"],
      ["6", "Daily"],
      ["7", "Weekly"],
      ["8", "Monthly_by_Date"],
      ["9", "Monthly_by_Day"],
      ["10", "Yearly"],
	  ["0", "To Do Next"],
	  ["11", "Pick a date"],
           ["12", "Someday / Maybe"]
      
      ]
      
      FREQ_INTERVALS_DAILY = [
      ["1", "Every Day"],
      ["2", "Every Other Day"],
      ["3", "Every 3rd Day"],
      ["4", "Every 4th Day"],
      ["5", "Every 5th Day"]
      ]
      
      FREQ_INTERVALS_WEEKLY = [
      ["1", "Every Week"],
      ["2", "Every Other Week"],
      ["3", "Every 3rd Week"],
      ["4", "Every 4th Week"],
      ["5", "Every 5th Week"]
      ]
      
      FREQ_INTERVALS_MONTHLY = [
      ["1", "Every Month"],
      ["2", "Every Other Month"],
      ["3", "Every 3rd Month"],
      ["4", "Every 4th Month"],
      ["5", "Every 5th Month"],
      ["6", "Every 6th Month"],
      ["7", "Every 7th Month"],
      ["8", "Every 8th Month"],
      ["9", "Every 9th Month"],
      ["10", "Every 10th Month"],
      ["11", "Every 11th Month"],
      ["12", "Every 12th Month"]
      ]
      
      FREQ_INTERVALS_YEARLY = [
      ["1", "Every Year"],
      ["2", "Every Other Year"],
      ["3", "Every 3rd Year"],
      ["4", "Every 4th Year"],
      ["5", "Every 5th Year"],
      ["6", "Every 6th Year"],
      ["7", "Every 7th Year"],
      ["8", "Every 8th Year"],
      ["9", "Every 9th Year"],
      ["10", "Every 10th Year"],
      ["11", "Every 11th Year"],
      ["12", "Every 12th Year"]
      ]
      
      FREQ_INTERVALS_QUAL_DATE = [
      ["1", "1st"],
      ["2", "2nd"],
      ["3", "3rd"],
      ["4", "4th"],
      ["5", "5th"],
      ["6", "6th"],
      ["7", "7th"],
      ["8", "8th"],
      ["9", "9th"],
      ["10", "10th"],
      ["11", "11th"],
      ["12", "12th"],
      ["13", "13th"],
      ["14", "14th"],
      ["15", "15th"],
      ["16", "16th"],
      ["17", "17th"],
      ["18", "18th"],
      ["19", "19th"],
      ["20", "20th"],
      ["21", "21th"],
      ["22", "22th"],
      ["23", "23th"],
      ["24", "24th"],
      ["25", "25th"],
      ["26", "26th"],
      ["27", "27th"],
      ["28", "28th"],
      ["29", "29th"],
      ["30", "30th"],
      ["31", "Last"]
      ]
      
      FREQ_INTERVALS_QUAL_WEEKLY = [
      ["1", "Sunday"],
      ["2", "Monday"],
      ["3", "Tuesday"],
      ["4", "Wedneday"],
      ["5", "Thursday"],
      ["6", "Friday"],
      ["7", "Saturday"]
      ]
      
      FREQ_INTERVALS_QUAL_DAY= [
      ["1", "1st Sunday"],
      ["2", "1st Monday"],
      ["3", "1st Tuesday"],
      ["4", "1st Wedneday"],
      ["5", "1st Thursday"],
      ["6", "1st Friday"],
      ["7", "1st Saturday"],
      
      ["8", "2nd Sunday"],
      ["9", "2nd Monday"],
      ["10", "2nd Tuesday"],
      ["11", "2nd Wedneday"],
      ["12", "2nd Thursday"],
      ["13", "2nd Friday"],
      ["14", "2nd Saturday"],
      
      ["15", "3rd Sunday"],
      ["16", "3rd Monday"],
      ["17", "3rd Tuesday"],
      ["18", "3rd Wedneday"],
      ["19", "3rd Thursday"],
      ["20", "3rd Friday"],
      ["21", "3rd Saturday"],
      
      ["22", "4th Sunday"],
      ["23", "4th Monday"],
      ["24", "4th Tuesday"],
      ["25", "4th Wedneday"],
      ["26", "4th Thursday"],
      ["27", "4th Friday"],
      ["28", "4th Saturday"],
      
       ["29", "Last Sunday"],
      ["30", "Last Monday"],
      ["31", "Last Tuesday"],
      ["32", "Last Wedneday"],
      ["33", "Last Thursday"],
      ["34", "Last Friday"],
      ["35", "Last Saturday"]



      ]
   PRIORITY = {
                                1 => "Low",
                                2 => "Medium",
                                3 => "High"
                             }
end