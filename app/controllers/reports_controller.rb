# app/controllers/reports_controller.rb

class ReportsController < ApplicationController

  def index
		@start_date = nil
		@end_date = nil
		@start_age = params[:startAge]
		@end_age = params[:endAge]
		@type = params[:selType]

		case params[:selSelect]
		when "day"
		@start_date = params[:day]
		@end_date = params[:day]
		when "week"
		@start_date = (("#{params[:selYear]}-01-01".to_date) + (params[:selWeek].to_i * 7)) -
		("#{params[:selYear]}-01-01".to_date.strftime("%w").to_i)
		@end_date = (("#{params[:selYear]}-01-01".to_date) + (params[:selWeek].to_i * 7)) +
		6 - ("#{params[:selYear]}-01-01".to_date.strftime("%w").to_i)
		when "month"
			@start_date = ("#{params[:selYear]}-#{params[:selMonth]}-01").to_date.strftime("%Y-%m-%d")
			@end_date = ("#{params[:selYear]}-#{params[:selMonth]}-#{ (params[:selMonth].to_i != 12 ?
		("#{params[:selYear]}-#{params[:selMonth].to_i + 1}-01".to_date - 1).strftime("%d") : "31") }").to_date.strftime("%Y-%m-%d")
		when "year"
			@start_date = ("#{params[:selYear]}-01-01").to_date.strftime("%Y-%m-%d")
			@end_date = ("#{params[:selYear]}-12-31").to_date.strftime("%Y-%m-%d")
		when "quarter"
			day = params[:selQtr].to_s.match(/^min=(.+)&max=(.+)$/)
			@start_date = (day ? day[1] : Date.today.strftime("%Y-%m-%d"))
			@end_date = (day ? day[2] : Date.today.strftime("%Y-%m-%d"))
		when "range"
			@start_date = params[:start_date]
			@end_date = params[:end_date]
		end

		report = Reports.new(@start_date, @end_date, @start_age, @end_age, @type)

		@observations_1 = report.observations_1

		@observations_2 = report.observations_2

		@observations_3 = report.observations_3

		@observations_4 = report.observations_4

		@observations_5 = report.observations_5

		@week_of_first_visit_1 = report.week_of_first_visit_1

		@week_of_first_visit_2 = report.week_of_first_visit_2

		@pre_eclampsia_1 = report.pre_eclampsia_1

		@pre_eclampsia_2 = report.pre_eclampsia_2

		@ttv__total_previous_doses_1 = report.ttv__total_previous_doses_1

		@ttv__total_previous_doses_2 = report.ttv__total_previous_doses_2

		@fansida__sp___number_of_tablets_given_1 = report.fansida__sp___number_of_tablets_given_1

		@fansida__sp___number_of_tablets_given_2 = report.fansida__sp___number_of_tablets_given_2

		@fefo__number_of_tablets_given_1 = report.fefo__number_of_tablets_given_1

		@fefo__number_of_tablets_given_2 = report.fefo__number_of_tablets_given_2

		@syphilis_result_1 = report.syphilis_result_1

		@syphilis_result_2 = report.syphilis_result_2

		@syphilis_result_3 = report.syphilis_result_3

		@hiv_test_result_1 = report.hiv_test_result_1

		@hiv_test_result_2 = report.hiv_test_result_2

		@hiv_test_result_3 = report.hiv_test_result_3

		@hiv_test_result_4 = report.hiv_test_result_4

		@hiv_test_result_5 = report.hiv_test_result_5

		@on_art__1 = report.on_art__1

		@on_art__2 = report.on_art__2

		@on_art__3 = report.on_art__3

		@on_cpt__1 = report.on_cpt__1

		@on_cpt__2 = report.on_cpt__2

		@pmtct_management_1 = report.pmtct_management_1

		@pmtct_management_2 = report.pmtct_management_2

		@pmtct_management_3 = report.pmtct_management_3

		@pmtct_management_4 = report.pmtct_management_4

		@nvp_baby__1 = report.nvp_baby__1

		@nvp_baby__2 = report.nvp_baby__2

    render :layout => false
  end
  
	def report
		@start_date = nil
		@end_date = nil
		@start_age = params[:startAge]
		@end_age = params[:endAge]
		@type = params[:selType]

		case params[:selSelect]
		when "day"
		@start_date = params[:day]
		@end_date = params[:day]
		when "week"
		@start_date = (("#{params[:selYear]}-01-01".to_date) + (params[:selWeek].to_i * 7)) -
		("#{params[:selYear]}-01-01".to_date.strftime("%w").to_i)
		@end_date = (("#{params[:selYear]}-01-01".to_date) + (params[:selWeek].to_i * 7)) +
		6 - ("#{params[:selYear]}-01-01".to_date.strftime("%w").to_i)
		when "month"
			@start_date = ("#{params[:selYear]}-#{params[:selMonth]}-01").to_date.strftime("%Y-%m-%d")
			@end_date = ("#{params[:selYear]}-#{params[:selMonth]}-#{ (params[:selMonth].to_i != 12 ?
		("#{params[:selYear]}-#{params[:selMonth].to_i + 1}-01".to_date - 1).strftime("%d") : "31") }").to_date.strftime("%Y-%m-%d")
		when "year"
			@start_date = ("#{params[:selYear]}-01-01").to_date.strftime("%Y-%m-%d")
			@end_date = ("#{params[:selYear]}-12-31").to_date.strftime("%Y-%m-%d")
		when "quarter"
			day = params[:selQtr].to_s.match(/^min=(.+)&max=(.+)$/)
			@start_date = (day ? day[1] : Date.today.strftime("%Y-%m-%d"))
			@end_date = (day ? day[2] : Date.today.strftime("%Y-%m-%d"))
		when "range"
			@start_date = params[:start_date]
			@end_date = params[:end_date]
		end

		report = Reports.new(@start_date, @end_date, @start_age, @end_age, @type)

		@observations_1 = report.observations_1

		@observations_2 = report.observations_2

		@observations_3 = report.observations_3

		@observations_4 = report.observations_4

		@observations_5 = report.observations_5

		@week_of_first_visit_1 = report.week_of_first_visit_1

		@week_of_first_visit_2 = report.week_of_first_visit_2

		@pre_eclampsia_1 = report.pre_eclampsia_1

		@pre_eclampsia_2 = report.pre_eclampsia_2

		@ttv__total_previous_doses_1 = report.ttv__total_previous_doses_1

		@ttv__total_previous_doses_2 = report.ttv__total_previous_doses_2

		@fansida__sp___number_of_tablets_given_1 = report.fansida__sp___number_of_tablets_given_1

		@fansida__sp___number_of_tablets_given_2 = report.fansida__sp___number_of_tablets_given_2

		@fefo__number_of_tablets_given_1 = report.fefo__number_of_tablets_given_1

		@fefo__number_of_tablets_given_2 = report.fefo__number_of_tablets_given_2

		@syphilis_result_1 = report.syphilis_result_1

		@syphilis_result_2 = report.syphilis_result_2

		@syphilis_result_3 = report.syphilis_result_3

		@hiv_test_result_1 = report.hiv_test_result_1

		@hiv_test_result_2 = report.hiv_test_result_2

		@hiv_test_result_3 = report.hiv_test_result_3

		@hiv_test_result_4 = report.hiv_test_result_4

		@hiv_test_result_5 = report.hiv_test_result_5

		@on_art__1 = report.on_art__1

		@on_art__2 = report.on_art__2

		@on_art__3 = report.on_art__3

		@on_cpt__1 = report.on_cpt__1

		@on_cpt__2 = report.on_cpt__2

		@pmtct_management_1 = report.pmtct_management_1

		@pmtct_management_2 = report.pmtct_management_2

		@pmtct_management_3 = report.pmtct_management_3

		@pmtct_management_4 = report.pmtct_management_4

		@nvp_baby__1 = report.nvp_baby__1

		@nvp_baby__2 = report.nvp_baby__2

    render :layout => false
	end

	def select
	end

end
