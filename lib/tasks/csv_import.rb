class CsvImport
  include ActiveModel::Model

  attr_writer :filepath

  def save!
    CSV.foreach(filepath, headers: true) do |row|
      ap row
      result = ScrbClient.post("/stories", body: row.to_h.to_json)
      binding.pry unless result[:code] == "201"
    end
  end

  def filepath
    @filepath ||= "stories.csv"
  end
end
