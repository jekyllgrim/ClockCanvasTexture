version "4.12"

class GrandfatherClock : Actor
{
	Default
	{
		+SOLID
		+DECOUPLEDANIMATIONS
		height 80;
		radius 10;
	}

	States {
	Spawn:
		BAL1 A -1 NoDelay SetAnimation('swing', 10, flags:SAF_LOOP);
		stop;
	}
}

class ClockHandler : EventHandler
{
	const CLOCKANG_360 = 360.0;
	ui transient Canvas clockFace_Canvas;
	ui transient Vector2 clockFace_size;
	ui transient Shape2D clockHands_Hour;
	ui transient Shape2D clockHands_Minute;
	ui transient Shape2D clockHands_Second;
	ui transient Shape2DTransform clockHands_transform;
	ui transient TextureID clockface_texture;
	ui transient String clockface_texture_name;
	ui transient Color clockface_handsColor;

	// This returns 3 ints: hours, minutes, and seconds.
	// By default gets system time. Modify it to supply
	// any desired time instead. Note, this has to be ui-scoped.
	ui int, int, int GetClockTime()
	{
		int systime = SystemTime.Now();
		String h = SystemTime.Format("%I", systime);
		String m = SystemTime.Format("%M", systime);
		String s = SystemTime.Format("%S", systime);

		int hours = h.ToInt(10);
		int minutes = m.ToInt(10);
		int seconds = s.ToInt(10);

		return hours, minutes, seconds;
	}

	// Creates shapes and defines other values for the clock:
	ui void InitClock()
	{
		// The name/path to the texture used as the background
		// for the clock:
		clockface_texture_name = "models/clockface.png";
		// The color of the hands (black by default):
		clockface_handsColor = 0x000000;
		// The name of the CANVASTEXTURE defined in ANIMDEFS.
		// By default it's "ClockFace_Canvas" and it's 256x256. It can
		// be scaled in Ultimate Doom Builder to apply it to
		// a smaller linedef:
		String canvasName = "ClockFace_Canvas";

		// This normally doesn't need to be touched.
		// Sets up the canvas and necessary values:
		TextureID tid = TexMan.CheckForTexture(canvasName);
		clockFace_size = TexMan.GetScaledSize(tid);
		clockFace_Canvas = TexMan.GetCanvas(canvasName);
		
		// Initalize Shape2DTransform used by the hands:
		clockHands_transform = new('Shape2DTransform');
		
		// Hands are simple squared (although hour and minute
		// are tapered to be trapezoids), and they could optionally
		// be textured (I'm pushing valid coordinates to them).
		// The actual drawing happens later, in UpdateHandShape().

		// Hour:
		double width, height;
		clockHands_Hour = new('Shape2D');
		width = 0.03;
		height = 0.15;
		clockHands_Hour.PushVertex((-width, 0.0));
		clockHands_Hour.PushVertex((width, 0.0));
		clockHands_Hour.PushVertex((-width*0.3, height));
		clockHands_Hour.PushVertex((width*0.3,height));
		clockHands_Hour.PushCoord((0,1));
		clockHands_Hour.PushCoord((1,1));
		clockHands_Hour.PushCoord((0,0));
		clockHands_Hour.PushCoord((1,0));
		clockHands_Hour.PushTriangle(0, 1, 2);
		clockHands_Hour.PushTriangle(1, 2, 3);

		// Minute:
		clockHands_Minute = new('Shape2D');
		width = 0.025;
		height = 0.35;
		clockHands_Minute.PushVertex((-width, 0.0));
		clockHands_Minute.PushVertex((width, 0.0));
		clockHands_Minute.PushVertex((-width*0.35, height));
		clockHands_Minute.PushVertex((width*0.35, height));
		clockHands_Minute.PushCoord((0,1));
		clockHands_Minute.PushCoord((1,1));
		clockHands_Minute.PushCoord((0,0));
		clockHands_Minute.PushCoord((1,0));
		clockHands_Minute.PushTriangle(0, 1, 2);
		clockHands_Minute.PushTriangle(1, 2, 3);

		// Second (very thin):
		clockHands_Second = new('Shape2D');
		width = 0.0075;
		height = 0.4;
		clockHands_Second.PushVertex((-width, 0.0));
		clockHands_Second.PushVertex((width, 0.0));
		clockHands_Second.PushVertex((-width, height));
		clockHands_Second.PushVertex((width, height));
		clockHands_Second.PushCoord((0,1));
		clockHands_Second.PushCoord((1,1));
		clockHands_Second.PushCoord((0,0));
		clockHands_Second.PushCoord((1,0));
		clockHands_Second.PushTriangle(0, 1, 2);
		clockHands_Second.PushTriangle(1, 2, 3);
	}

	// This moves the hand further by upadting its transform.
	// shape - the necessary shape
	// pos - the position of the hand's origin (normally this
	// would be the center of the canvas)
	// angle - the angle of the hand
	ui void UpdateHandShape(Shape2D shape, Vector2 pos, double angle)
	{
		clockHands_transform.Clear();
		clockHands_transform.Scale(clockFace_size);
		clockHands_transform.Rotate(angle + 180);
		clockHands_transform.Translate(pos);
		shape.SetTransform(clockHands_transform);
		// Convert color from RGB to BGR, since that's what DrawShapeFill uses:
		Color col = color(clockface_handsColor.b, clockface_handsColor.g, clockface_handsColor.r);
		// Note, DrawShape could be used instead to draw a textured hand:
		clockFace_Canvas.DrawShapeFill(col, 1.0, shape);
	}

	override void UiTick()
	{
		if (!(clockFace_Canvas && clockHands_Hour && clockHands_Minute && clockHands_Second && clockHands_transform))
		{
			InitClock();
			return;
		}

		// canvas center:
		Vector2 clockcenter = clockFace_size * 0.5;

		int hours, minutes, seconds;
		[hours, minutes, seconds] = GetClockTime();

		// We have to clear the canvas with each step, otherwise the previously
		// drawn hands will not be erased:
		clockFace_Canvas.Clear(0, 0, clockFace_size.x, clockFace_size.y, -1);
		// So, we also need to redraw the background every step:
		if (!clockface_texture)
		{
			clockface_texture = TexMan.CheckForTexture(clockface_texture_name);
		}
		clockFace_Canvas.DrawTexture(clockface_texture, false, 
			0, 0,
			DTA_DestWidthF, clockFace_size.x,
			DTA_DestHeightF, clockFace_size.y
		);

		// Move hours. Note that it doesn't move in 12-step increments, but moves
		// gradually towards the next hour:
		UpdateHandShape(clockHands_Hour, clockcenter, (CLOCKANG_360 / 12) * hours + (CLOCKANG_360 / 12 / 60) * minutes);
		// Move minutes (60 increments):
		UpdateHandShape(clockHands_Minute, clockcenter, (CLOCKANG_360 / 60) * minutes);
		// Move seconds (60 increments):
		UpdateHandShape(clockHands_Second, clockcenter, (CLOCKANG_360 / 60) * seconds);

		//Console.PrintF("Drawing clock shapes %d %d %d", hours, minutes, seconds);
	}
}