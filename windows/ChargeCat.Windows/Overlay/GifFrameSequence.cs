using System.Drawing;
using System.Drawing.Imaging;
using System.Linq;

namespace ChargeCat.WindowsApp.Overlay;

internal sealed class GifFrameSequence : IDisposable
{
    private readonly List<Bitmap> _frames;

    private GifFrameSequence(List<Bitmap> frames, List<int> delaysMs, Size canvasSize)
    {
        _frames = frames;
        DelaysMs = delaysMs;
        CanvasSize = canvasSize;
    }

    public IReadOnlyList<Bitmap> Frames => _frames;
    public IReadOnlyList<int> DelaysMs { get; }
    public Size CanvasSize { get; }
    public int FrameCount => _frames.Count;

    public static GifFrameSequence Load(string path)
    {
        using var gif = Image.FromFile(path);
        var dimension = new FrameDimension(gif.FrameDimensionsList[0]);
        var frameCount = gif.GetFrameCount(dimension);
        var delays = ReadFrameDelays(gif, frameCount);
        var frames = new List<Bitmap>(frameCount);

        for (var index = 0; index < frameCount; index++)
        {
            gif.SelectActiveFrame(dimension, index);
            var bitmap = new Bitmap(gif.Width, gif.Height);
            using var graphics = Graphics.FromImage(bitmap);
            graphics.Clear(Color.Transparent);
            graphics.DrawImage(gif, 0, 0, gif.Width, gif.Height);
            frames.Add(bitmap);
        }

        return new GifFrameSequence(frames, delays, new Size(gif.Width, gif.Height));
    }

    public Bitmap GetFrame(int index)
    {
        var resolvedIndex = Math.Clamp(index, 0, _frames.Count - 1);
        return _frames[resolvedIndex];
    }

    public void Dispose()
    {
        foreach (var frame in _frames)
        {
            frame.Dispose();
        }
    }

    private static List<int> ReadFrameDelays(Image gif, int frameCount)
    {
        const int PropertyTagFrameDelay = 0x5100;
        if (gif.PropertyIdList.Contains(PropertyTagFrameDelay) == false)
        {
            return Enumerable.Repeat(40, frameCount).ToList();
        }

        var propertyItem = gif.GetPropertyItem(PropertyTagFrameDelay);
        var delays = new List<int>(frameCount);
        for (var index = 0; index < frameCount; index++)
        {
            var offset = index * 4;
            var delay = BitConverter.ToInt32(propertyItem.Value, offset) * 10;
            delays.Add(Math.Max(delay, 30));
        }

        return delays;
    }
}
