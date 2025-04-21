module Jekyll
  class CardTag < Liquid::Tag

    def initialize(tag_name, text, tokens)
      super
      @text = text
    end

    def render(context)
      title, card = parse_parameters context
"<a class='link' href='#'>
[#{title}]
<img class='preview-card' src='/assets/ahlcg/#{card}.jpg'>
</a>"
    end
    
    def parse_parameters(context)
      parameters = Liquid::Template.parse(@markup).render context
      return parameters, parameters.gsub(/['".?]/, '').downcase
    end
  end
  
  class InvestigatorTag < Liquid::Tag

    def initialize(tag_name, text, tokens)
      super
      @text = text
    end

    def render(context)
      title, card = parse_parameters context
"<a class='link' href='#'>
[#{title}]
<img class='preview-investigator-front' src='/assets/ahlcg/#{card} front.jpg'>
<img class='preview-investigator-back' src='/assets/ahlcg/#{card} back.jpg'>
</a>"      
    end
    
    def parse_parameters(context)
      parameters = Liquid::Template.parse(@markup).render context
      return parameters, parameters.gsub(/['".?]/, '').downcase
    end
  end
  
  class InlineCardTag < Liquid::Tag

    def initialize(tag_name, text, tokens)
      super
      @text = text
    end

    def render(context)
      title, card = parse_parameters context
"<img class='inline-card' src='/assets/ahlcg/#{card}.jpg'>"
    end
    
    def parse_parameters(context)
      parameters = Liquid::Template.parse(@markup).render context
      return parameters, parameters.gsub(/['".?]/, '').downcase
    end
  end
  
  class Icon < Liquid::Tag

    def initialize(tag_name, text, tokens)
      super
      @text = text
    end

    def render(context)
      token = parse_parameters context
      if token == "fail"
        "<span class='token'>z</span>"
      elsif token == "skull"
        "<span class='token'>n</span>"
      elsif token == "tab"
        "<span class='token'>v</span>"
      elsif token == "tent"
        "<span class='token'>c</span>"
      elsif token == "cult"
        "<span class='token'>b</span>"
      elsif token == "elder"
        "<span class='token'>x</span>"
      elsif token == "+1"
        "<span class='token'>+1</span>"
      elsif token == "0"
        "<span class='token'>0</span>"
      elsif token == "-1"
        "<span class='token'>-1</span>"
      elsif token == "-2"
        "<span class='token'>-2</span>"
      elsif token == "-3"
        "<span class='token'>-3</span>"
      elsif token == "-4"
        "<span class='token'>-4</span>"
      elsif token == "-4"
        "<span class='token'>-4</span>"
      elsif token == "bless"
        "<span class='token'>l</span>"
      elsif token == "curse"
        "<span class='token'>m</span>"
      elsif token == "trigger"
        "<span class='token'>my</span>"
      elsif token == "free"
        "<span class='token'>u</span>"
      elsif token == "agi"
        "<span class='token'>s</span>"
      elsif token == "str"
        "<span class='token'>d</span>"
      elsif token == "int"
        "<span class='token'>f/span>"
      elsif token == "will"
        "<span class='token'>a/span>"
      end
    end
    
    def parse_parameters(context)
      parameters = Liquid::Template.parse(@markup).render context
      return parameters
    end
  end
end

Liquid::Template.register_tag('card', Jekyll::CardTag)
Liquid::Template.register_tag('investigator', Jekyll::InvestigatorTag)
Liquid::Template.register_tag('inline', Jekyll::InlineCardTag)
Liquid::Template.register_tag('icon', Jekyll::Icon)