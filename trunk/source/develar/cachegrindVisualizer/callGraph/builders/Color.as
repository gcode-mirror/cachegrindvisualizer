package develar.cachegrindVisualizer.callGraph.builders
{
	import develar.cachegrindVisualizer.callGraph.Node;
	
	public class Color
	{
		public function build(node:Node):String
		{
			var colorValue:Number = node.percentage / 100;
				
			var hue:Number = 0.6 + colorValue;
			if (hue > 1)
			{
				hue = 1;
			}
				
			var saturation:Number = 0.1 + colorValue;
			if (saturation > 1)
			{
				saturation = 1;
			}
				
			var brightness:Number = 1;
				
			return hue + ' ' + saturation + ' ' + brightness;
		}
	}
}