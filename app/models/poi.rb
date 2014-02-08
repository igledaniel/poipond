class Poi < ActiveRecord::Base

  serialize :tags, Hash

  has_many :poi_categories
  has_many :categories, through: :poi_categories

  validates :osm_type, :name, :lat, :lon, presence: true
  validates :osm_type, inclusion: { in: %w(node way relation) }

  scope :closest, lambda { |lat, lon, count=10, distance=1|
    select("*,
      (6378*acos(cos(radians(#{lat}))*cos(radians(lat))*
      cos(radians(lon)-radians(#{lon}))+sin(radians(#{lat}))*
      sin(radians(lat)))) AS distance").
    where("lat BETWEEN #{lat-(distance/111.045)} AND #{lat+(distance/111.045)} AND
           lon BETWEEN #{lon}-(#{distance}/(111.045 * COS(RADIANS(#{lat})))) AND
                       #{lon}+(#{distance}/(111.045 * COS(RADIANS(#{lat}))))").
    order('distance').
    limit(count)
  }

  def display_category
    if categories.count <= 1
      categories.first
    else
      # category with parent is more specific, preferred
      categories.select { |c| !c.parent_id.nil? }.first
    end
  end

  def to_xml(changeset, user)
    xml = "<osm>"
    xml << "<#{osm_type} visible=\"true\" "
    xml << "id=\"#{osm_id}\" " unless osm_id.nil?
    xml << "version=\"#{version}\" " unless version.nil?
    xml << "changeset=\"#{changeset.id}\" timestamp=\"#{Time.now.utc}\" "
    xml << "user=\"#{user.display_name}\" uid=\"#{user.uid}\" "
    xml << "lat=\"#{lat}\" lon=\"#{lon}\">"
    xml << encode_tags
    xml << "</#{osm_type}>"
    xml << "</osm>"
    xml
  end

  def encode_tags
    self.tags[:name] = name unless name.nil?
    self.tags[:addr_housenumber] = addr_housenumber unless addr_housenumber.nil?
    self.tags[:addr_street] = addr_street unless addr_street.nil?
    self.tags[:addr_city] = addr_city unless addr_city.nil?
    self.tags[:addr_postcode] = addr_postcode unless addr_postcode.nil?
    self.tags[:phone] = phone unless phone.nil?
    self.tags[:website] = website unless website.nil?
    categories.map(&:tags).each { |th| self.tags = tags.merge(th) }
    parents = categories.map(&:parent)
    parents.map(&:tags).each { |th| self.tags = tags.merge(th) }
    self.tags = self.tags.delete_if { |k,v| v.blank? }
    xml = ''
    self.tags.each do |k,v|
      key = k.to_s.gsub('_', ':')
      val = CGI::escapeHTML(v)
      xml << "<tag k=\"#{key}\" v=\"#{val}\"/>"
    end
    xml
  end

  def self.decode_tags(tags)
    hash = {}
    tags.each do |tag|
      key = tag['k'].gsub(':', '_')
      hash[key] = tag['v']
    end
    hash.symbolize_keys
  end

end
