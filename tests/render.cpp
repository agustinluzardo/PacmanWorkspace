#include <QGuiApplication>
#include <QQuickView>
#include <QQuickItem>
#include <QQmlError>
#include <QTimer>
#include <QImage>
#include <QColor>
#include <QUrl>
#include <QDebug>
#include <QCoreApplication>
#include <QStringList>
#include <QProcessEnvironment>
#include <QTest>

int main(int argc, char **argv) {
    QGuiApplication app(argc, argv);
    if (argc < 3) {
        qWarning() << "usage: render <file.qml> <out.png> [grabMs]   (PROBE=\"x,y;x,y\" prints pixels)";
        return 2;
    }

    QQuickView view;
    view.setResizeMode(QQuickView::SizeViewToRootObject);
    view.setSource(QUrl::fromLocalFile(QString::fromLocal8Bit(argv[1])));

    if (view.status() == QQuickView::Error) {
        for (const QQmlError &e : view.errors()) qWarning().noquote() << "QML ERROR:" << e.toString();
        return 1;
    }
    view.show();
    // Hover delivery needs an exposed window; without this the synthetic move is
    // accepted and then dropped.
    if (!QTest::qWaitForWindowExposed(&view, 2000))
        qWarning() << "window never exposed - hover injection will not work";

    // HOVER="x,y@ms" parks the pointer on a sprite. QTest::mouseMove goes in at
    // the platform layer, which is what Qt Quick turns into the hover events a
    // MouseArea reads; sending a QMouseEvent straight to the window does not
    // reach it offscreen.
    const QString hover = QProcessEnvironment::systemEnvironment().value("HOVER");
    if (!hover.isEmpty()) {
        const QStringList parts = hover.split(QLatin1Char('@'));
        const QStringList xy = parts[0].split(QLatin1Char(','));
        if (xy.size() == 2) {
            const int hx = xy[0].trimmed().toInt();
            const int hy = xy[1].trimmed().toInt();
            const int at = parts.size() > 1 ? parts[1].toInt() : 100;
            QTimer::singleShot(at, [&view, hx, hy]() {
                QTest::mouseMove(&view, QPoint(hx, hy));
                qInfo().noquote() << "HOVER at" << hx << hy;
            });
        }
    }

    int rc = 0;
    QTimer::singleShot(argc > 3 ? QString::fromLocal8Bit(argv[3]).toInt() : 1200, [&]() {
        QImage img = view.grabWindow();
        if (img.isNull()) { qWarning() << "grab failed"; rc = 1; }
        else if (!img.save(QString::fromLocal8Bit(argv[2]))) { qWarning() << "save failed"; rc = 1; }
        else qInfo().noquote() << "saved" << argv[2] << img.width() << "x" << img.height();

        // PROBE="x,y;x,y" prints the rendered colour at those points. A repaint
        // bug shows up as the right value in QML and the wrong pixel on screen,
        // so the pixel is the only thing that actually settles it.
        const QString probe = QProcessEnvironment::systemEnvironment().value("PROBE");
        if (!probe.isEmpty() && !img.isNull()) {
            const QStringList points = probe.split(QLatin1Char(';'), Qt::SkipEmptyParts);
            for (const QString &pt : points) {
                const QStringList xy = pt.split(QLatin1Char(','));
                if (xy.size() != 2) continue;
                const int x = xy[0].trimmed().toInt();
                const int y = xy[1].trimmed().toInt();
                if (x < 0 || y < 0 || x >= img.width() || y >= img.height()) {
                    qInfo().noquote() << "PIXEL" << x << y << "out-of-range";
                    continue;
                }
                const QColor c = img.pixelColor(x, y);
                qInfo().noquote() << "PIXEL" << x << y << c.name();
            }
        }
        app.quit();
    });
    app.exec();
    return rc;
}
