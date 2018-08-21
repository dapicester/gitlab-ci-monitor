def symbolize_keys(hash)
  hash.inject({}) do |result, (key, value)|
    new_key = case key
              when String then key.to_sym
              else key
              end
    new_value = case value
                when Hash then symbolize_keys(value)
                else value
                end
    result[new_key] = new_value
    result
  end
end

def load_projects(filename)
  data = YAML.load_file 'projects.yml'
  data.map { |el| symbolize_keys el }
end
