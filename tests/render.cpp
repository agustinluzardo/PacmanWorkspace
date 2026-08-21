#include <QGuiApplication>
#include <QQuickView>
#include <QQuickItem>
#include <QQmlError>
#include <QTimer>
#include <QImage>
#include <QUrl>
#include <QDebug>

int main(int argc, char **argv) {
    QGuiApplication app(argc, argv);
    if (argc < 3) { qWarning() << "usage: render <file.qml> <out.png>"; return 2; }

    QQuickView view;
    view.setResizeMode(QQuickView::SizeViewToRootObject);
    view.setSource(QUrl::fromLocalFile(QString::fromLocal8Bit(argv[1])));

    if (view.status() == QQuickView::Error) {
        for (const QQmlError &e : view.errors()) qWarning().noquote() << "QML ERROR:" << e.toString();
        return 1;
    }
    view.show();

    int rc = 0;
    QTimer::singleShot(argc > 3 ? QString::fromLocal8Bit(argv[3]).toInt() : 1200, [&]() {
        QImage img = view.grabWindow();
        if (img.isNull()) { qWarning() << "grab failed"; rc = 1; }
        else if (!img.save(QString::fromLocal8Bit(argv[2]))) { qWarning() << "save failed"; rc = 1; }
        else qInfo().noquote() << "saved" << argv[2] << img.width() << "x" << img.height();
        app.quit();
    });
    app.exec();
    return rc;
}
