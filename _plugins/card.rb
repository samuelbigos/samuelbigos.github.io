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
  
  class Chaos < Liquid::Tag

    def initialize(tag_name, text, tokens)
      super
      @text = text
    end

    def render(context)
      token = parse_parameters context
      "<span class='token'>z</span>"
      if token == "autofail"
        "<span class='token'>z</span>"
      elsif token == "skull"
        "<span class='token'>n</span>"
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
Liquid::Template.register_tag('chaos', Jekyll::Chaos)