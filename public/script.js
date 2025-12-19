document.addEventListener('DOMContentLoaded', () => {
    const elementsToAnimate = document.querySelectorAll('.animate-on-scroll');
    const buttons = document.querySelectorAll('.cta-buttons .button');

    const animateOnScroll = () => {
        elementsToAnimate.forEach(element => {
            const rect = element.getBoundingClientRect();
            if (rect.top < window.innerHeight) {
                element.classList.add('visible');
            }
        });

        buttons.forEach((button, index) => {
            const rect = button.getBoundingClientRect();
            if (rect.top < window.innerHeight) {
                setTimeout(() => {
                    button.classList.add('visible');
                }, index * 200); // Staggered delay
            }
        });
    };

    window.addEventListener('scroll', animateOnScroll);
    animateOnScroll(); // Initial check
});
