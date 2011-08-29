class LabController < ApplicationController
  def results
    @results = []
    @patient = Patient.find(params[:id])
    (Lab.results(@patient) || []).map do | short_name , test_name , range , value , test_date |
      @results << [short_name.gsub('_',' '),"/lab/view?test=#{short_name}&patient_id=#{@patient.id}"]
    end
    render :layout => 'menu'
  end

  def view
    @patient = Patient.find(params[:patient_id])
    @test = params[:test]
    @results = Lab.results_by_type(@patient,@test)
    @table_th = build_table(@results) unless @results.blank?
    render :layout => 'menu'
  end

  def build_table(results)
    available_dates = Array.new()
    available_test_types = Array.new()
    html_tag = Array.new()
    html_tag_to_display = nil

    results.each do | key , values |
      date = key.split("::")[0].to_date rescue 'Unknown'
      available_dates << date
      available_test_types << key.split("::")[1]
    end

    available_dates = available_dates.compact.uniq.sort.reverse rescue []
    available_test_types = available_test_types.compact.uniq rescue []
    return if available_dates.blank?


    #from the available test dates we create 
    #the top row which holds all the lab run test date  - quick hack :)
    @table_tr = "<tr><th>&nbsp;</th>" ; count = 0
    available_dates.map do | date |
      @table_tr += "<th id='#{count+=1}'>#{date}</th>"
    end ; @table_tr += "</tr>"

    #same here - we create all the row which will hold the actual 
    #lab results .. quick hack :)
    @table_tr_data = '' 
    available_test_types.map do | type |
      @table_tr_data += "<tr><td><a href = '#' onmousedown=\"graph('#{type}');\">#{type.gsub('_',' ')}</a></td>"
      count = 0
      available_dates.map do | date |
        @table_tr_data += "<td id = '#{type}_#{count+=1}' id='#{date}::#{type}'></td>"
      end
      @table_tr_data += "</tr>"
    end

    results.each do | key , values |
      value = values['Range'] + ' ' + values['TestValue']
      @table_tr_data = @table_tr_data.sub(" id='#{key}'>"," class=#{}>#{value}")
    end


    return (@table_tr + @table_tr_data)
  end

  def graph
    @results = []
    params[:results].split(';').map do | result |
      date = result.split(',')[0].to_date rescue '1900-01-01'
      value = result.split(',')[1].sub('<','').sub('>','').sub('=','')
      @results << [ date , value ]
    end 
    @patient = Patient.find(params[:patient_id])
    @type = params[:type]
    @test = params[:test]
    render :layout => 'menu'
  end

end
